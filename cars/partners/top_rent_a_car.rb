require 'httparty'

class Api::V1::Car::Index::Partners::TopRentACar
  include HTTParty

  base_uri 'http://toprentacar.bg/xml_gate/'

  class << self

    # Get cars from TopRentACar only by dates
    def get_cars(location, date_from, date_to)

      date_from = date_from + 'T12:00:00'
      date_to = date_to + 'T12:00:00'

      pull_cars(location, date_from, date_to)
    end

    # Get cars from TopRentACar by date and time
    def pull_cars(location, date_from, date_to)

      current_location = ''

      # Get CityCode by CityName
      current_locale = I18n.locale
      I18n.available_locales.each do |l|
        I18n.locale = l
        city = City.find_by(name: location)
        if city.present?
          current_location = city.location_code
          break
        end
      end
      I18n.locale = current_locale
      
      headers = { Authorization: 'Basic ZGFyZW50YTpkQHJlbnRANTYzMw=='}

      # Create xml body for response
      body = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        request = xml.Request do
          xml.ResRates do
            xml.Partner.Code="darenta"
            
            pickup = xml.Pickup
            pickup.dateTime=date_from
            pickup.locationCode=current_location

            ret = xml.Return
            ret.dateTime=date_to
            ret.locationCode=location
          end
        end
        request.referenceNumber="23de0a9186adf56b3e580b7eb2c9ab45"
        request.version="3.0"
        request.xmlns="http://toprentacar.bg/xml/"
      end

      # Create request hash
      options = { headers: headers, body: body.to_xml }

      # Send request and get response
      response = post('/', options)

      return nil unless response.success?

      result = parse_response(response.body)
      result = create_cars(result, date_from, date_to, current_location)

      result
    end

    # Parse TopRentACar response
    def parse_response(response)
      partner_cars = []

      xml_doc = Nokogiri::XML(response)
      xml_doc.search('Response ResRates Rate').each do |car|

        attributes = {
          RateID: car.at('RateID').text,
          ACRISS: car.at('ACRISS').text,
          Availability: car.at('Availability').text,
          TotalCost: car.at('TotalCost').text,
          CurrencyCode: car.at('CurrencyCode').text,
          CarName: car.at('CarName').text,
          Gearbox: car.at('Gearbox').text,
          Fuel: car.at('Fuel').text,
          RequestRate: car.at('RequestRate').text
        }

        net_rate_xml = car.at('NetRate')
        if net_rate_xml.present?
          attributes[:NetRate] = net_rate_xml.text
        end

        delivery_xml = car.at('Delivery')
        if delivery_xml.present?
          attributes[:Delivery] = delivery_xml.text
        end

        out_of_hours_xml = car.at('OutOfHours')
        if out_of_hours_xml.present?
          attributes[:OutOfHours] = out_of_hours_xml.text
        end

        seats_xml = car.at('Seats')
        if seats_xml.present?
          attributes[:Seats] = seats_xml.text
        end

        doors_xml = car.at('Doors')
        if doors_xml.present?
          attributes[:Doors] = doors_xml.text
        end

        bags_big_xml = car.at('BagsBig')
        if bags_big_xml.present?
          attributes[:BagsBig] = bags_big_xml.text
        end

        air_con_xml = car.at('AirCon')
        if air_con_xml.present?
          attributes[:AirCon] = air_con_xml.text
        end

        wheel_drive_xml = car.at('WheelDrive')
        if wheel_drive_xml.present?
          attributes[:WheelDrive] = wheel_drive_xml.text
        end

        partner_cars << attributes
      end

      partner_cars
    end

    # Create cars from partner response
    def create_cars(partner_cars, date_from, date_to, location_code)
      days = (Date.parse(date_to.to_s) - Date.parse(date_from.to_s)).to_i

      cars = []

      partner_cars.each do |car|
        price_rub = PartnerCar.new.rub_from_eur(car[:TotalCost])
        price_usd = PartnerCar.new.rub_to_usd(price_rub)
        price_krw = PartnerCar.new.rub_to_krw(price_rub)

        attributes = {
          rate_id: car[:RateID],
          acriss_code: car[:ACRISS],
          availability: car[:Availability],
          net_rate: car[:NetRate],
          delivery: car[:Delivery],
          out_of_hours: car[:OutOfHours],
          total_cost: car[:TotalCost],
          currency_code: car[:CurrencyCode],
          car_name: car[:CarName],
          seats: car[:Seats],
          doors: car[:Doors],
          gearbox: car[:Gearbox],
          bags_big: car[:BagsBig],
          air_con: car[:AirCon],
          wheel_drive: car[:WheelDrive],
          fuel: car[:Fuel],
          request_rate: car[:RequestRate],

          price_rub: (price_rub.to_f / days).round(2),
          price_usd: (price_usd.to_f / days).round(2),
          price_krw: (price_krw.to_f / days).round(2),
          price_eur: (car[:TotalCost].to_f / days).round(2),
          is_current_offer: true,
          location_code: location_code
        }

        if car[:Gearbox] == 'a'
          attributes[:transmission_id] = 1
        elsif car[:Gearbox] == 'm'
          attributes[:transmission_id] = 2
        end

        if car[:Fuel] == 'petrol'
          attributes[:engine_id] = 1
        elsif car[:Fuel] == 'diesel' 
          attributes[:engine_id] = 2
        end

        cars << ::PartnerCar.new(attributes)
      end

      cars
    end

  end
end

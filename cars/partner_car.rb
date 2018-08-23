class PartnerCar < ApplicationRecord

  # Receiving current exchange rates crom cbr 
  def pull_currencies
    url = URI.parse('http://www.cbr.ru/scripts/XML_daily.asp')
    request = Net::HTTP::Get.new(url.to_s)
    result = Net::HTTP.start(url.host, url.port) {|http|
      http.request(request)
    }
    result.body
  end

  # Get currency value by currency code
  def get_currency_value(currency_code)
    nominal = 1
    value = 1

    all_currencies_xml = pull_currencies

    xml_doc = Nokogiri::XML(all_currencies_xml)
    xml_doc.search('ValCurs Valute').each do |valute|
      if valute.at('CharCode').text == currency_code
        nominal = valute.at('Nominal').text
        value = valute.at('Value').text
      end
    end

    return nominal, value
  end
  
  # Convert eur to rub
  def rub_from_eur(value)
    nominal, value_in_rub = get_currency_value('EUR')
    value = ((value_in_rub.to_f / nominal.to_f).round(2) * value.to_f).to_f.round(2)
    value
  end

  # Convert rub to usd
  def rub_to_usd(value)
    nominal, value_in_rub = get_currency_value('USD')
    value = (value.to_f / ((value_in_rub.to_f / nominal.to_f).round(2))).to_f.round(2)
    value
  end

  # Convert rub to krw
  def rub_to_krw(value)
    nominal, value_in_rub = get_currency_value('KRW')
    value = (value.to_f / ((value_in_rub.to_f / nominal.to_f).round(2))).to_f.round(2)
    value
  end
end

require 'dry/transaction'

class Api::V1::Order::CreatePartnerCarRequest::Interactor
  include Dry::Transaction

  ISO_8601_REGEX = /^\d\d\d\d-(0?[1-9]|1[0-2])-(0?[1-9]|[12][0-9]|3[01])$/

  # Car params validation
  VALIDATOR = Dry::Validation.Form do
    required(:car_price).filled(:float?)
    required(:car_name).filled(:str?)
    required(:tenant_email).filled(format?: ::Regex::Email.new.plain)
    required(:date_from).filled(format?: ISO_8601_REGEX)
    required(:date_to).filled(format?: ISO_8601_REGEX)
    required(:is_need_redirect).filled(:bool?)
    required(:partner_token).filled(:str?)

    optional(:where_to_pickup).maybe(:str?)
    optional(:where_to_leave).maybe(:str?)
    optional(:discount).maybe(:str?)
    optional(:discount_type).maybe(:str?)
    optional(:locale).value(included_in?: %w(ru en ko))    
  end

  step :symbolize
  step :merge_defaults
  step :cast
  step :validate
  step :check_tenant
  step :create_order

  # Convert params to symbols
  def symbolize(params)
    Success params.symbolize_keys
  end

  # Apply default settings
  def merge_defaults(params)
    params[:locale] = 'ru' unless params[:locale].present?
    Success params
  end

  # Cast params hash to params structure
  def cast(params)
    Success Api::V1::Order::CreatePartnerCarRequest::Structure.new(params.to_h).to_h
  end

  # Validate params
  def validate(hash)
    result = VALIDATOR.call(hash)
    result.success? ? Success(result) : Failure(result.errors)
  end

  # Check tenant for existance
  def check_tenant(hash)
    account = ::TenantAccount.find_by(email: hash[:tenant_email])
    tenant = ::Tenant.find_by(id: account.tenant_id)
    tenant.is_blocked ? Failure({ tenant: ['is blocked'] }) : Success(hash)
  end

  # Create Order
  def create_order(hash)
    hash = hash.to_h

    # Find tenant
    account = ::TenantAccount.find_by(email: hash[:tenant_email])
    tenant = ::Tenant.find_by(id: account.tenant_id)
    tenant.locale = hash[:locale]
    tenant.save

    price = ::Order.new.calculate_comission(car_price, date_from, date_to)

    discount = create_discount(hash)
    if discount.present?
      price = ::Order.new.apply_discount(price)
    end

    price_currency = "rub"

    if discount.present?
      discount_value = discount.value
      discount_type = ::DiscountType.find_by(id: discount.type_id).title
    end
    
    landlord_id = nil

    emails = []
    accounts = ::TenantAccount.where(tenant_id: tenant.id)
    accounts.each do |account|
      emails << account.email
    end

    # Create order params hash
    order_params = {
      :car_id => nil,
      :car_name => hash[:car_name],
      :car_price => hash[:car_price],
      :tenant_id => tenant.id,
      :tenant_first_name => tenant.first_name,
      :tenant_last_name => tenant.last_name,
      :tenant_full_name => tenant.full_name,
      :tenant_phone => tenant.phone,
      :tenant_accounts => emails,
      :discount_type => discount_type,
      :discount_value => discount_value,
      :landlord_id => landlord_id,
      :rent_from => hash[:date_from],
      :rent_til => hash[:date_to],
      :where_to_pickup => hash[:where_to_pickup],
      :where_to_leave => hash[:where_to_leave],
      :price_value => price,
      :price_currency => price_currency,
      :is_paid => false,
      :paid_at => nil,
      :is_need_redirect => hash[:is_need_redirect],
      :partner_token => hash[:partner_token],
      :locale => hash[:locale]
    }

    order = ::Order.create(order_params)
    order.save

    hash[:price_value] = order.price_value
    hash[:price_currency] = order.price_currency
    hash[:order_uid] = order.id
    hash[:signature] = ::Order.new.generate_create_signature(order)

    Success(hash)
  end

  private

  # Create discount
  def create_discount(hash)
    discount = nil
    if hash[:discount].present? && hash[:discount_type].present?
      if ::DiscountType.where(title: hash[:discount_type]).exists?
        discount_type = ::DiscountType.find_by(title: hash[:discount_type])
        discount_params = { :type_id => discount_type.id,
                            :value => hash[:discount]
        }
        discount = ::Discount.create(discount_params)
        discount.save
      end
    end
    discount
  end
end

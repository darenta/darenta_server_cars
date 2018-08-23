require 'dry-types'
require 'dry-struct'

Dry::Types.load_extensions(:maybe)
module Types
  include Dry::Types.module
end

# Car params Structure
class Api::V1::Order::CreatePartnerCarRequest::Structure < Dry::Struct
  constructor_type :schema

  # Day price
  attribute :car_price, Types::Coercible::Float.optional

  # Car full name
  attribute :car_name, Types::Coercible::String.optional

  # Owner email
  attribute :tenant_email, Types::Coercible::String.optional

  # Rent start date
  attribute :date_from, Types::Coercible::String.optional

  # Rent end date
  attribute :date_to, Types::Coercible::String.optional

  # Where to start rent
  attribute :where_to_pickup, Types::Coercible::String.optional

  # Where to finish rent
  attribute :where_to_leave, Types::Coercible::String.optional

  # Discount
  attribute :discount, Types::Coercible::String.optional

  # Discount type id
  attribute :discount_type, Types::Coercible::String.optional

  # Locale
  attribute :locale, Types::Coercible::String.default('ru')

  # Response should be redirected to partner service
  attribute :is_need_redirect, Types::Coercible::Int.optional

  # Car uid
  attribute :partner_token, Types::Coercible::String.optional

end

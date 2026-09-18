class Staff < ApplicationRecord
  self.table_name = 'staff'

  ROLES = %w[cashier supervisor manager admin].freeze

  attr_accessor :pin

  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: ROLES }
  validates :pin_hash, presence: true

  before_validation :hash_pin, if: -> { pin.present? }

  has_many :shifts, foreign_key: :cashier_id, dependent: :restrict_with_error
  has_many :authorized_drawer_events, class_name: 'DrawerEvent', foreign_key: :authorized_by, dependent: :nullify

  def authenticate_pin(candidate_pin)
    return false if pin_hash.blank? || candidate_pin.blank?

    BCrypt::Password.new(pin_hash) == candidate_pin.to_s
  rescue BCrypt::Errors::InvalidHash
    false
  end

  private

  def hash_pin
    self.pin_hash = BCrypt::Password.create(pin.to_s)
  end
end

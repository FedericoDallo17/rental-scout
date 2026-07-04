class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :search_preferences, dependent: :destroy

  validates :first_name, presence: true
  validates :last_name, presence: true
end

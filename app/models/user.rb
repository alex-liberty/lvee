require 'net/smtp'
require 'uri'
require 'resolv'

class User < ActiveRecord::Base
  devise :database_authenticatable, :confirmable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  EMAIL_REGEXP = /\A[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]+\z/
  include UserConcern

  mount_uploader :avator, UserUploader

  has_many :conference_registrations, :dependent => :delete_all
  has_and_belongs_to_many :abstracts, :join_table => "users_abstracts", :uniq => true

  # Virtual attribute for the unencrypted password
  attr_reader :password

  # Virtual attribute for disable mail sending
  attr_accessor :no_mail


  REQUIRED_FIELDS = [:country, :city, :occupation]

  validates *REQUIRED_FIELDS, :presence => true

  PASSWORD_VALIDATOR =  {:if => :password_required?, :presence => true, :length => {:within => 4..40}}

  validates :login, :presence => true, :length => {:within => 3..40}, :uniqueness => {:case_sensitive => false}

  validates :first_name, :presence => true, :length => {:within => 2..30}
  validates :last_name, :presence => true, :length => {:within => 2..30}
  validate :if_real_name_is_real, on: :create

  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.

  def full_name
    "#{first_name} #{last_name}"
  end

  def from
    "#{city}, " + country.to_s
  end

  def editable_by?(user)
    self.id == user.id # by self and only self ;)
  end

  def admin?
    self.role == 'admin'
  end

  def editor?
    ['admin', 'editor'].include?(self.role)
  end

  def reviewer?
    ['admin', 'editor', 'reviewer'].include?(self.role)
  end

  def self.valid_data
    {:login => 'login', :email => 'user@example.com',
      :first_name => 'Vasiliy', :last_name=> 'Pupkin',
      :country => 'belarus', :city => 'Minsk',
      :password => '1234',
      :password_confirmation => '1234',
      :occupation => "Some",
      :projects => "Any"}
  end

  def to_s
    "#{full_name}"
  end

  def loaded?
    true
  end

  def self.create_imported(base)
    u = User.new
    base.each_pair do |k, v|
      unless %w(site id age profession avator role).include? k
        u.send((k + "=").to_sym, v)
      end
    end
    u.no_mail = true
    if(u.save)
      if base['activated_at']
        u.no_mail = true
        u.activate
      end
      "User #{u.login} (#{u.email}) has been created"
    else
      "Error saving user #{u.login} (#{u.email}): <ul><li>" + u.errors.full_messages.join("</li><li>") + "</li></ul>"
    end
  end

  protected
  def if_real_name_is_real
    if first_name == last_name
      errors.add :last_name, :invalid
    end
  end
end

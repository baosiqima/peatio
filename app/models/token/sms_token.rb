class Token::SmsToken < ::Token

  VERIFICATION_CODE_LENGTH = 6

  attr_accessor :phone_number
  attr_accessor :verify_code

  validates_uniqueness_of :token, scope: :member_id
  validates :phone_number, phone: { possible: true,
                                    allow_blank: true,
                                    types: [:mobile] }

  def generate_token
    begin
      self.token = VERIFICATION_CODE_LENGTH.times.map{ Random.rand(9) + 1 }.join
      self.expire_at = DateTime.now.since(60 * 30)
    end while Token::SmsToken.where(member_id: member_id, token: token).any?
  end

  def update_phone_number
    phone = Phonelib.parse(phone_number)
    member.update phone_number: phone.international.to_s
  end

  def send_verify_code
    update_phone_number
    AMQPQueue.enqueue(:sms_notification, phone: member.phone_number, message: sms_message)
  end

  def sms_message
    I18n.t('sms.verification_code', code: token)
  end

  def verify?
    if token == verify_code
      true
    else
      errors.add(:verify_code, I18n.t("errors.messages.invalid"))
      false
    end
  end

  def verified!
    self.update is_used: true
    member.sms_two_factor.active!
    MemberMailer.phone_number_verified(member.id).deliver
  end

end

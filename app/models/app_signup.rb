class AppSignup < Signup

#validates :parent, :presence => true
#validates :waiver, :acceptance => true

  def default_url_options
    { :host => 'localhost:3000'}
  end

  def process_apprent_fee
    logger.info "Processing payment"
    unless charge_id.present?
      charge = Stripe::Charge.create(
        :amount => 2900, # amount in cents, again
        :currency => "usd",
        :card => stripe_card_token,
        :description => "Apprenticeship fee for #{self.event.title} from #{self.user.email}"
      )
      update_attribute(:charge_id, charge.id)
      logger.info "Processed payment #{charge.id}"
    end
  rescue Stripe::InvalidRequestError => e
    logger.error "Stripe error while creating charge: #{e.message}"
    errors.add :base, "There was a problem with your credit card."
    false
  end

  def deliver_save
    Pony.mail({
      :to => "#{user.name}<#{user.email}>",
          :from => "GirlsGuild<hello@girlsguild.com>",
      :reply_to => "GirlsGuild<hello@girlsguild.com>",
      :subject => "Your application has been saved - #{self.event.title}",
      :html_body => %(<h1>Word!</h1> <p>We're thrilled you're applying to work with #{self.event.host_firstname}! If you get stuck take a look at our <a href="http://www.girlsguild.com/faq">FAQ</a>, or feel free to respond to this email with any questions you might have!</p> <p>You can edit your application here - <a href="#{url_for(self)}"> Application for #{self.event.title}</a></p>),
      :bcc => "hello@girlsguild.com",
    })
    return true
  end

  def deliver
    return false unless valid?
    Pony.mail({
      :to => "#{user.name}<#{user.email}>",
          :from => "GirlsGuild<hello@girlsguild.com>",
      :reply_to => "GirlsGuild<hello@girlsguild.com>",
      :subject => "Application for #{event.title}",
      :html_body => %(<h1>Thanks!</h1> <p>You've applied for <a href=#{url_for(event)}>#{event.title}</a>. You can see your application <a href=#{url_for(self)}>here</a>. #{event.host_firstname} will review it, and we'll let you know her decision within two weeks.</p>),
      :bcc => "hello@girlsguild.com",
    })
    return true
  end

  def deliver_decline
    Pony.mail({
      :to => "#{user.name}<#{user.email}>",
          :from => "GirlsGuild<hello@girlsguild.com>",
      :reply_to => "GirlsGuild<hello@girlsguild.com>",
      :subject => "#{self.event.host_firstname} reviewed your application",
      :html_body => %(<p>Thanks for your application! For this apprenticeship #{self.event.host_firstname} chose a different applicant, but she was super excited that you were interested in working together. We'll let you know about other possibilities for collaboration with her in the future. In the meantime, we hope you'll find another apprenticeship you'd be interested in - check out our <a href="#{url_for(apprenticeships_path)}"> our apprenticeship listings</a></p>),
      :bcc => "hello@girlsguild.com",
    })
    return true
  end

  def deliver_accept
    Pony.mail({
      :to => "#{user.name}<#{user.email}>",
          :from => "GirlsGuild<hello@girlsguild.com>",
      :reply_to => "GirlsGuild<hello@girlsguild.com>",
      :subject => "#{self.event.host_firstname} would like to work with you!",
      :html_body => %(<h1>Yeehaw!</h1> <p>We're excited to let you know that #{self.event.host_firstname} has reviewed your application for #{self.event.title} and would like to work with you as her apprentice! To accept the apprenticeship, please fill out the <a href=#{url_for(self)}>confirmation form</a> and submit your apprenticeship fee. If you have any questions feel free to respond to this email.</p>),
      :bcc => "hello@girlsguild.com",
    })
    return true
  end

  def deliver_confirm
    return false unless valid?
    Pony.mail({
      :to => "#{user.name}<#{user.email}>",
          :from => "GirlsGuild<hello@girlsguild.com>",
      :reply_to => "GirlsGuild<hello@girlsguild.com>",
      :subject => "Your apprenticeship is ready to start! - #{self.event.title}",
      :html_body => %(<h1>Yesss!</h1> <p>You're all confirmed for #{self.event.title}! (Fill out this email with more info)</p>),
      :cc => "#{event.user.name}<#{event.user.email}>",
      :bcc => "hello@girlsguild.com",
    })
    return true
  end

  def self.complete_app_signup
    app_signups = self.event.where(:ends_at => Date.today).all
    app_signups.each {|a| a.complete}
  end

  state_machine :state, :initial => :started do
    event :complete do
      transition :confirmed => :completed
    end
  end
end
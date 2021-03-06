require 'stripe'
require 'stripe_mock'

describe User do

  before(:each) do
    StripeMock.start
    FactoryGirl.reload
    @user = FactoryGirl.build(:user, email: 'test@example.com')
  end

  after(:each) do
    StripeMock.stop
    Warden.test_reset!
  end
    
  it { should respond_to(:email) }

  it "#email returns a string" do
    expect(@user.email).to match 'test@example.com'
  end

  it "should create a new instance given a valid attribute" do
    @user.email = 'valid@example.com'
    expect(@user.save).to be true
  end

  it "should require an email address" do
    expect(@user.email = "").to_not be true
  end

  it "should accept valid email addresses" do
    addresses = %w[user@foo.com THE_USER@foo.bar.org first.last@foo.jp]
    addresses.each do |address|
    expect(@user.email = address).to be_truthy
    end
  end

  it "should reject invalid email addresses" do
    addresses = %w[user@foo,com user_at_foo.org example.user@foo.]
    addresses.each do |address|
      invalid_email_user = FactoryGirl.build(:user, email: address)
      expect(invalid_email_user.save).to_not be_truthy
    end
  end

  it "should reject duplicate email addresses" do
    @user.save
    expect(FactoryGirl.build(:user)).to be_invalid
  end

  it "should reject email addresses identical up to case" do
    @user.save
    expect(FactoryGirl.create(:user, email: 'example@example.com'.upcase)).to_not be_invalid
  end
end

describe "Passwords" do

  before(:each) do
    StripeMock.start
    FactoryGirl.reload
    @user = FactoryGirl.build(:user, email: 'test@example.com')
  end

  after(:each) do
    StripeMock.stop
    Warden.test_reset!
  end

  it "should have a password attribute" do
    expect(@user).to respond_to(:password)
    end

  it "should have a password confirmation attribute" do
    expect(@user).to respond_to(:password_confirmation)
  end
end

describe "password validations" do

  before(:each) do
    StripeMock.start
    FactoryGirl.reload
    @user = FactoryGirl.build(:user, email: 'test@example.com')
  end

  after(:each) do
    StripeMock.stop
    Warden.test_reset!
  end

  it "should require a password" do
    @user.password = ""
    expect(@user.save).to_not be_truthy
  end

  it "should require a matching password confirmation" do
    original_user_password = @user.password
    @user.password = "different"
    @user.save
    expect(@user.password).to_not eq original_user_password
  end

  it "should reject short passwords" do
    short = "a" * 5
    @user = FactoryGirl.build(:user, password: short, password_confirmation: short)
    expect(@user.save).to_not be_truthy
  end
end

describe "password encryption" do

  before(:each) do
    StripeMock.start
    FactoryGirl.reload
    @user = FactoryGirl.build(:user, email: 'test@example.com')
  end

  after(:each) do
    StripeMock.stop
    Warden.test_reset!
  end

  it "should have an encrypted password attribute" do
    expect(@user).to respond_to(:encrypted_password)
  end

  it "should set the encrypted password attribute" do
    expect(@user.encrypted_password).to be_truthy
  end
end

describe "expire" do

  before(:each) do
    StripeMock.start
    FactoryGirl.reload
    @user = FactoryGirl.build(:user, email: 'test@example.com')
  end

  after(:each) do
    StripeMock.stop
    Warden.test_reset!
  end


   it "sends an email to user", live: true do
     StripeMock.start
     plan = stripe_helper.create_plan(id: 'silver', name: 'Silver', amount: 900)
     token = stripe_helper.generate_card_token(card_number: '4242424242424242')
     customer = Stripe::Customer.create({
       email: 'johnny@appleseed.com',
       source: token
     })
     expect(customer.subscriptions.data).to be_empty
     expect(customer.subscriptions.count).to eq(0)
     expect(token).to match /^test_tok/
     subscription = customer.subscriptions.create(plan: "silver", metadata: { foo: "bar", example: "yes" })
     subscription.metadata['foo'] = 'bar'
     expect(subscription.object).to eq('subscription')
     expect(subscription.plan.to_hash).to eq(plan.to_hash)
     expect(subscription.metadata.foo).to eq( "bar" )
     expect(subscription.metadata.example).to eq( "yes" )
     customer = Stripe::Customer.retrieve(customer.id)
     expect(customer.subscriptions.data).to_not be_empty
     expect(customer.subscriptions.count).to eq(1)
     expect(customer.subscriptions.data.length).to eq(1)
     expect(customer.subscriptions.data.first.id).to eq(subscription.id)
     expect(customer.subscriptions.data.first.plan.to_hash).to eq(plan.to_hash)
     expect(customer.subscriptions.data.first.customer).to eq(customer.id)
     expect(customer.subscriptions.data.first.metadata.foo).to eq( "bar" )
     expect(customer.subscriptions.data.first.metadata.example).to eq( "yes" )
     expect(customer.email).to eq('johnny@appleseed.com')
     expect(customer.subscriptions.first.plan.id).to eq('silver')
     expect(customer.subscriptions.first.metadata['foo']).to eq('bar')
     @user = User.new(email: "johnny@appleseed.com", stripe_token: token, name: 'tester', password: 'changeme', password_confirmation: 'changeme')
     @role = FactoryGirl.create(:role, name: "silver")
     @user.add_role(@role.name)
     Rails.logger.info(puts "#{@user.inspect}")
     expect(@user.roles.first.name).to eq 'silver'
     @user.update!(customer_id: customer.id)
     @user.update!(email: 'emailtouser@example.com')
     expired = UserMailer.expire_email(@user)
     expect(expired.pretty_inspect).to match /#<Mail::Message/
     expect(expired.pretty_inspect).to match /Multipart: true/
     expect(expired.pretty_inspect).to match /Headers: \<From: do-not-reply\@example\.com\>/
     expect(expired.pretty_inspect).to match /\<To: emailtouser\@example\.com\>/
     expect(expired.pretty_inspect).to match /\<Subject: Subscription Cancelled\>/
     expect(expired.pretty_inspect).to match /\<Mime-Version: 1\.0\>/
     expect(expired.pretty_inspect).to match /\<Content-Type: multipart\/alternative;/
     expect(expired.pretty_inspect).to match /boundary\=\"--\=\=\_mimepart\_/
     expect(expired.pretty_inspect).to match /charset=UTF-8\>/
    #expect(ActionMailer::Base.deliveries.last.to).to eq @user.email # => NoMethodError: undefined method `to' for nil:NilClass
    #expect(ActionMailer::Base.deliveries.size).to eq 1
    #expect(ActionMailer::Base.deliveries.last).to eq([@user.email])
    #expect(ActionMailer::Base.deliveries.last.to).to eq([@user.email])
    StripeMock.stop
      end
    end
    expect(ActionMailer::Base.deliveries.last).to eq @user.email
  end
end

describe "#update_plan", :devise do

  let(:user) { FactoryGirl.build(:user) }

  after(:each) do
    Warden.test_reset!
  end

  it "updates a users role" do
    StripeMock.start
    user.save
    expect(user.role).to eq 'user'
    user.role = 1
    expect(user.role).to eq 'admin'
    user.role = 2
    expect(user.role).to eq 'silver'
    expect(user.role).to_not eq 'admin'
    StripeMock.stop
  end
end

describe ".update_stripe", :devise do
  context "with a non-existing user" do  

    before do
      StripeMock.start
      @user = FactoryGirl.build(:user, email: 'test@example.com')
###   successful_stripe_response = StripeHelper::Response.new("success")
###   Stripe::Customer.mock(:create).and_return(successful_stripe_response)
      card_token = StripeMock.generate_card_token(number: "4242424242424242", exp_month: 2, exp_year: 2017)
      @customer = Stripe::Customer.create(card: card_token)
      @user.role = "silver"
    end

    after do
      Warden.test_reset!
      StripeMock.stop
    end

    it "creates a new user with a succesful stripe response" do
      expect(@user.save!).to be true
     #expect(successful_stripe_response).to be true
    end
  end
end
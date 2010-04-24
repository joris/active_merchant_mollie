require "spec_helper.rb"

describe "Mollie iDeal implementation for ActiveMerchant" do
  
  it "should create a new billing gateway with a required partner id" do
    ActiveMerchant::Billing::MollieIdealGateway.new(:partner_id  => 123456).should be_kind_of(ActiveMerchant::Billing::MollieIdealGateway)
  end
  
  it "should throw an error if a gateway is created without a partner id" do
    lambda {
      ActiveMerchant::Billing::MollieIdealGateway.new
    }.should raise_error(ArgumentError)
  end
  
  context "setup purchase" do
    
    before do
      @login       = 123456
      @return_url  = "http://www.example.com/mollie/return"
      @report_url  = "http://www.example.com/mollie/report"
      @issuer_id   = "0031"
      @description = "This is a test transaction"
      @gateway     = ActiveMerchant::Billing::MollieIdealGateway.new(:login  => @login)
    end
    
    it "should create a new purchase via the Mollie API" do
      http_mock = mock(Net::HTTP)      
      Net::HTTP.should_receive(:new).with("secure.mollie.nl", 443).and_return(http_mock)
      
      response_mock = mock(Net::HTTPResponse)
      response_mock.should_receive(:body).and_return('<?xml version="1.0"?>
      <response>
          <order>
              <transaction_id>482d599bbcc7795727650330ad65fe9b</transaction_id>
              <amount>123</amount>
              <currency>EUR</currency>
              <URL>https://mijn.postbank.nl/internetbankieren/SesamLoginServlet?sessie=ideal&trxid=003123456789123&random=123456789abcdefgh</URL>
              <message>Your iDEAL-payment has succesfuly been setup. Your customer should visit the given URL to make the payment</message>
          </order>
      </response>')
      
      http_mock.should_receive(:get) do |url|
        { :partnerid => @login, :returnurl => @return_url, :reporturl => @report_url, :description => CGI::escape(@description), :bank_id => @issuer_id }.each do |param, value|
          url.should include("#{param}=#{value}")
        end
        response_mock
      end
      
      @response = @gateway.setup_purchase(1000, {
        :return_url       => @return_url,
        :report_url       => @report_url,
        :issuer_id        => @issuer_id,
        :description      => @description
      })
      
      @response.token.should == "482d599bbcc7795727650330ad65fe9b"
      @gateway.redirect_url_for(@response.token).should == "https://mijn.postbank.nl/internetbankieren/SesamLoginServlet?sessie=ideal&trxid=003123456789123&random=123456789abcdefgh"
    end
    
    it "should not allow a purchase without a return url" do
      lambda {
        @gateway.setup_purchase(1000, {
          :report_url       => @report_url,
          :issuer_id        => @issuer_id,
          :description      => @description
        })
      }.should  raise_error(ArgumentError)
    end
    
    it "should not allow a purchase without a report url" do
      lambda {
        @gateway.setup_purchase(1000, {
          :return_url       => @return_url,
          :issuer_id        => @issuer_id,
          :description      => @description
        })
      }.should  raise_error(ArgumentError)
    end
    
    it "should not allow a purchase without an issuer id" do
      lambda {
        @gateway.setup_purchase(1000, {
          :return_url       => @return_url,
          :report_url       => @report_url,
          :description      => @description
        })
      }.should  raise_error(ArgumentError)
    end
    
    it "should not allow a purchase without a description" do
      lambda {
        @gateway.setup_purchase(1000, {
          :return_url       => @return_url,
          :report_url       => @report_url,
          :issuer_id        => @issuer_id
        })
      }.should  raise_error(ArgumentError)
    end
    
    it "should not allow a purchase with less than 1,80EUR" do
      lambda {
        @gateway.setup_purchase(179, {
          :return_url       => @return_url,
          :report_url       => @report_url,
          :issuer_id        => @issuer_id,
          :description      => @description
        })
      }.should  raise_error(ArgumentError)
    end
    
    it "should return information about the error Mollie is throwing" do
      http_mock = mock(Net::HTTP)      
      Net::HTTP.should_receive(:new).with("secure.mollie.nl", 443).and_return(http_mock)
      
      response_mock = mock(Net::HTTPResponse)
      response_mock.should_receive(:body).and_return('<?xml version="1.0"?>
      <response>
          <item>
              <errorcode>-10</errorcode>
              <message>This is an invalid order</message>
          </item>
      </response>')
      
      http_mock.should_receive(:get).and_return(response_mock)
      
      @response = @gateway.setup_purchase(1000, {
        :return_url       => @return_url,
        :report_url       => @report_url,
        :issuer_id        => @issuer_id,
        :description      => @description
      })
      @gateway.success?(@response).should be_false
      @response.message.should == "This is an invalid order (-10)"
    end
    
  end
  
  context "check details" do
    
    before do
      @login   = 123456
      @token   = "482d599bbcc7795727650330ad65fe9b"
      @gateway = ActiveMerchant::Billing::MollieIdealGateway.new(:login  => @login)
    end
    
    it "should return information about a successfull transaction" do
      http_mock = mock(Net::HTTP)      
      Net::HTTP.should_receive(:new).with("secure.mollie.nl", 443).and_return(http_mock)
      
      response_mock = mock(Net::HTTPResponse)
      response_mock.should_receive(:body).and_return('<?xml version="1.0"?>
      <response>
          <order>
              <transaction_id>482d599bbcc7795727650330ad65fe9b</transaction_id>
              <amount>123</amount>
              <currency>EUR</currency>
              <payed>true</payed>
              <consumer>
                  <consumerName>Hr J Janssen</consumerName>
                  <consumerAccount>P001234567</consumerAccount>
                  <consumerCity>Amsterdam</consumerCity>
              </consumer>
              <message>This iDEAL-order has successfuly been payed for, and this is the first time you check it.</message>
          </order>
      </response>')
      
      http_mock.should_receive(:get) do |url|
        { :partnerid => @login, :transaction_id => @token }.each do |param, value|
          url.should include("#{param}=#{value}")
        end
        response_mock
      end
      
      @details_response = @gateway.details_for(@token)
      @details_response.success?.should be_true
    end
    
    it "should return information about a successfull transaction" do
      http_mock = mock(Net::HTTP)      
      Net::HTTP.should_receive(:new).with("secure.mollie.nl", 443).and_return(http_mock)
      
      response_mock = mock(Net::HTTPResponse)
      response_mock.should_receive(:body).and_return('<?xml version="1.0"?>
      <response>
          <order>
              <transaction_id>482d599bbcc7795727650330ad65fe9b</transaction_id>
              <amount>123</amount>
              <currency>EUR</currency>
              <payed>false</payed>
              <message>This iDEAL-order has successfuly been payed for, and this is the first time you check it.</message>
          </order>
      </response>')
      
      http_mock.should_receive(:get) do |url|
        { :partnerid => @login, :transaction_id => @token }.each do |param, value|
          url.should include("#{param}=#{value}")
        end
        response_mock
      end
      
      @details_response = @gateway.details_for(@token)
      @details_response.success?.should be_false
    end
    
    it "should return information about the error Mollie is throwing" do
      http_mock = mock(Net::HTTP)      
      Net::HTTP.should_receive(:new).with("secure.mollie.nl", 443).and_return(http_mock)
      
      response_mock = mock(Net::HTTPResponse)
      response_mock.should_receive(:body).and_return('<?xml version="1.0"?>
      <response>
          <item>
              <errorcode>-10</errorcode>
              <message>This is an invalid order</message>
          </item>
      </response>')
      
      http_mock.should_receive(:get) do |url|
        { :partnerid => @login, :transaction_id => @token }.each do |param, value|
          url.should include("#{param}=#{value}")
        end
        response_mock
      end
      
      @details_response = @gateway.details_for(@token)
      @details_response.success?.should be_false
      @details_response.message.should == "This is an invalid order (-10)"
    end
    
  end
  
end
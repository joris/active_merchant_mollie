require "hpricot"

module ActiveMerchant
  module Billing
    class MollieIdealGateway < Gateway
      
      URL = "https://secure.mollie.nl/xml/ideal"
      
      # login is your Partner ID
      def initialize(options={})
        requires!(options, :login)
        
        @options = options
      end
      
      def setup_purchase(money, options)
        requires!(options, :return_url, :report_url, :issuer_id, :description)
        
        raise ArgumentError.new("Amount should be at least 1,80EUR") if money < 180
        
        build_purchase_response(commit('fetch', {
          :amount         => money,
          :bank_id        => options[:issuer_id],
          :description    => options[:description],
          :reporturl      => options[:report_url],
          :returnurl      => options[:return_url]
        }))
      end
      
      def details_for(token)
        build_details_response(commit('check', :transaction_id => token))
      end
      
      private
      
      def commit(action, parameters)
        # url = URL + "?" + post_data(action, parameters)
        # RAILS_DEFAULT_LOGGER.debug "MollieIdealGateway#commit POST url: #{url}"
        RAILS_DEFAULT_LOGGER.debug "MollieIdealGateway#commit POST action: #{action} parameters: #{parameters.inspect}"
        xml = ssl_post(URL, post_data(action, parameters))
        RAILS_DEFAULT_LOGGER.debug "MollieIdealGateway#commit response XML: #{xml}"
        parse(xml)
      end

      def post_data(action, parameters = {})
        add_pair(parameters, :partnerid, @options[:login])
        add_pair(parameters, :testmode, ActiveMerchant::Billing::Base.test?)
        add_pair(parameters, :a , action)
        parameters.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def add_pair(post, key, value, options = {})
        post[key] = value if !value.blank? || options[:required]
      end
      
      def success?(response)
        if response.search('response/item[@type="error"]').size == 0 && response.search('response/order').size > 0
          if response.at('response/order/payed')
            response.at('response/order/payed').inner_text.downcase == "true"
          else
            true
          end
        else
          false
        end
      end

      def message_from(response)
        if response.at('response/item[@type="error"]')
          errorcode = response.at('response/item[@type="error"]/errorcode').inner_text
          response.at('response/item[@type="error"]/message').inner_text + " (#{errorcode})"
        else
          response.at('response/order/message').inner_text
        end
      end
      
      def parse(xml)
        Hpricot.XML(xml)
      end
      
      def build_purchase_response(response)
        vars = {}
        if success?(response)
          options = {}
          order = response.at('response/order')
          if order && order.at('amount') && order.at('transaction_id') && order.at('URL')
            options[:amount]   = order.at('amount').inner_text
            options[:currency] = order.at('currency').inner_text
            options[:token]    = order.at('transaction_id').inner_text
            options[:url]      = order.at('URL').inner_text
          end
        end
        MollieIdealPurchaseResponse.new(success?(response), message_from(response), options)
      end
      
      def build_details_response(response)
        options = {}
        order   = response.at('response/order')
        
        if order
          options[:amount]   = order.at('amount').inner_text
          options[:currency] = order.at('currency').inner_text
          options[:token]    = order.at('transaction_id').inner_text
          options[:paid]     = order.at('payed').inner_text == "true"
        
          consumer = order.at('consumer')
          
          if consumer
            options[:account_holder] = consumer.at('consumer_name').inner_text
            options[:account_number] = consumer.at('consumer_account').inner_text
            options[:account_city]   = consumer.at('consumer_city').inner_text
          end
        end
        
        MollieIdealDetailsResponse.new(success?(response), message_from(response), options)
      end
      
    end
  end
end
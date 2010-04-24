module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MollieIdealPurchaseResponse < Response
    
      def token
        @params['token']
      end
      
      def amount
        @params['amount']
      end
      
      def currency
        @params['currency']
      end
      
      def url
        @params['url']
      end
      
    end
  end
end
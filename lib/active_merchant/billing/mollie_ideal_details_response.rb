module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MollieIdealDetailsResponse < Response
      
      def token
        @params['token']
      end
      
      def amount
        @params['amount']
      end

      def currency
        @params['currency']
      end
      
      def paid?
        @params['paid']
      end

      def account_holder
        @params['account_holder']
      end

      def account_number
        @params['account_number']
      end

      def account_city
        @params['account_city']
      end

    end
  end
end
require 'efatura/version'

module Efatura
  require 'mechanize'
  require 'rest-client'
  require 'date'
  require 'json'
  # EFATURA SCRAPER GEM. IT USES MECHANIZE TO SIMULATE A LOGIN TO EFATURA WEBSITE
  # IT THEN REDIRECTS TO CONSUMIDOR PAGE IN ORDER TO FETCH THE NECESSARY COOKIES
  # TO BUILD A REST-CLIENT REQUEST WITH COOKIES AS HEADERS
  # EFATURA WEBSITE IS POPULATED WITH AJAX REQUESTS
  # SO THE GOAL IS FETCH THE SAME JSONS THEY USE TO FEED DATA TO THE WEBSITE
  class Efatura
    attr_reader :nif, :password, :cookies, :s_date, :e_date
    attr_reader :login_url, :consumidor_url, :faturas_url
    # INITIALIZE WITH NIF PASSWORD STARTING DATE AND ENDIND DATE
    # ALL ARGUMENTS SHOULD BE STRINGS FOR THE INITIALIZER TO WORK
    # ALSO THIS GEM COMES PACKED WITH VALIDATIONS FOR DATE FOR A SIMPLE REASON
    # EFATURA CURRENTLY ONLY WORKS IF THE STARTING DATE AND ENDING DATE ARE
    # BOTH IN THE SAME YEAR OR ELSE THE JSON REQUEST WON'T BE SUCCESSFUL.
    # ALSO THE DATES SHOULD HAVE THIS FORMAT '2017-01-01' BUT IF THEY DON'T
    # THERE'S VALIDATIONS TO SKIP THE LOGIN
    def initialize(nif:, password:, s_date:, e_date:)
      @nif = nif
      @password = password
      @s_date = s_date
      @e_date = e_date
      @cookies = {}
      @login_url = 'https://www.acesso.gov.pt/jsp/loginRedirectForm.jsp?path=painelAdquirente.action&partID=EFPF'
      @consumidor_url = 'https://faturas.portaldasfinancas.gov.pt/painelAdquirente.action'
      @faturas_url = 'https://faturas.portaldasfinancas.gov.pt/json/obterDocumentosAdquirente.action'
    end

    def faturas
      # CALL THE SUCCESSFUL LOGIN
      login
      # SET THE RESPONSE REQUEST BY GIVING THE AJAX / JSON URL USED BY EFATURA
      # AND ASSIGNING THE COOKIE HEADERS
      response = RestClient::Request.execute(
        method: :get,
        url: faturas_url,
        cookies: cookies,
        headers: {
          params: {
            'dataInicioFilter' => s_date,
            'dataFimFilter' => e_date,
            'ambitoAquisicaoFilter' => 'TODOS'
          }
        }
      )
      # RETURNS ALL THE INVOICES REGISTED IN EFATURA AT THE GIVEN TIMEFRAME
      JSON.parse(response)
    end

    private

    def date_valid?
      # FOR A DATE TO BE VALID IT NEEDS TO PASS THE THREE CONDITIONS
      date_format_valid?(s_date) && date_format_valid?(e_date) && date_same_year?
    end

    def date_format_valid?(date)
      # RECEIVE A DATE INSTANCE VARIABLE AND VERIFIES THE CORRECT FORMAT
      format = '%Y-%m-%d'
      DateTime.strptime(date, format)
      true
    rescue ArgumentError
      false
    end

    def date_same_year?
      # ANALYZES IF BOTH DATES ARE FROM THE SAME YEAR
      s_date[0..3] == e_date[0..3]
    end

    def login
      # IF DATE IS VALID EXECUTES THE LOGIN METHOD
      if date_valid?
        # INITIATE A NEW MECHANIZE INSTANCE
        agent = Mechanize.new
        # FETCH THE LOGIN URL AND ITERATES THRO LOGIN_PAGE IN ORDER TO TARGET HTML COMPONENTS
        agent.get(login_url) do |login_page|
          # FETCHES THE LOGIN FORM FROM THE LOGIN PAGE
          login_form = login_page.form_with(name: 'loginForm')
          # SETS THE LOGIN USERNAME AKA NIF / NUMERO CONTRIBUINTE
          login_form.username = nif
          # SETS THE LOGIN PASSWORD
          login_form.password = password
          # SUBMITS THE FORM / LOGIN
          agent.submit(login_form)
          # AFTER A SUCCESSFUL LOGIN FETCH THE CONSUMIDOR PAGE IN ORDER TO RETRIEVE COOKIES
          consumidor_page = agent.get(consumidor_url)
          # ASSIGN THE CONSUMIDOR FORM TO A VARIABLE
          consumidor_form = consumidor_page.form_with(name: 'form')
          # SUBMIT THE FORM
          agent.submit(consumidor_form)
          # MAPS THE COOKIE_JAR FROM AGENT OBJECT AND FEEDS IT TO THE COOKIES HASH
          # THAT WAS INITIALIZED WITH AN EMPTY HASH
          @cookies = Hash[agent.cookie_jar.store.map { |i| i.cookie_value.split('=') }]
        end
      end
    end
  end
end
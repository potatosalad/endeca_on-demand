module EndecaOnDemand
  class Query

    include EndecaOnDemand::PP

    def inspect_attributes; [ :uri, :xml, :errors, :options ]; end

    ## fields ##

    attr_reader :body, :client, :errors, :http, :options, :response, :uri, :xml

    def initialize(client, options = {})
      @client, @options = client, options.dup.recurse(&:symbolize_keys)

      process_options!
    end

    ## associations ##

    def body
      @body ||= to_xml
    end

    def http
      @http ||= Net::HTTP.new(uri.host, uri.port)
    end

    def response
      @response ||= EndecaOnDemand::Response.new(self, http.post(uri.path, body, 'Content-type' => 'application/xml'))
    end

    def uri
      @uri ||= URI.parse(client.api)
    end

    def xml
      @xml ||= Nokogiri::XML(body) { |config| config.strict.noblanks }
    end

    ##

    ## xml builder ##

    def to_xml
      Builder::XmlMarkup.new(indent: 2).tag!(:Query) do |xml|

        Flags(xml)
        KeywordSearch(xml)
        NavigationQuery(xml)
        CategoryNavigationQuery(xml)
        Sorting(xml)
        Paging(xml)
        AdvancedParameters(xml)

      end
    end

    ### data ###

    def flags
      @flags ||= options[:flags] = (options[:flags] || {}).inject({}) do |hash,(key,value)|
          hash.tap do
            hash[key.to_s.underscore] = value
          end
        end.symbolize_keys
    end

    def searches
      @searches ||= options[:searches]
    end

    def dimensions
      @dimensions ||= [*options[:dimensions]]
    end

    def category
      @category ||= options[:category]
    end

    def sorts
      @sorts ||= options[:sorts]
    end

    def paging
      @paging ||= options[:paging] = (options[:paging] || {}).tap do |paging|
          if paging.has_key?(:page) and paging.has_key?(:per_page)
            paging[:offset] = (paging[:page].to_i * paging[:per_page].to_i rescue 0)
          end
        end
    end

    def advanced_parameters
      @advanced_parameters ||= options[:advanced] = (options[:advanced] || {}).inject({}) do |hash,(key,value)|
          hash.tap do
            hash[key.to_s.underscore] = value
          end
        end.symbolize_keys
    end

    ###

    protected

    def Flags(xml)
      return if flags.blank?
      flags.each do |flag,value|
        xml.tag!(flag.to_s.camelcase, value)
      end
    end

    def KeywordSearch(xml)
      return if searches.blank?
      xml.tag!(:Searches) do
        searches.each do |key,term|
          xml.tag!(:Search) do
            xml.tag!('search-key',  key.to_s)
            xml.tag!('search-term', term.to_s)
          end
        end
      end
    end

    def NavigationQuery(xml)
      return if dimensions.blank?
      xml.tag!(:SelectedDimensionValueIds) do
        dimensions.each do |dimension|
          xml.tag!(:DimensionValueId, dimension)
        end
      end
    end

    def CategoryNavigationQuery(xml)
      return if category.blank?
      xml.tag!(:Category) do
        xml.tag!(:CategoryId, category)
      end
    end

    def Sorting(xml)
      return if sorts.blank?
      xml.tag!(:Sorts) do
        sorts.each do |key,direction|
          xml.tag!(:Sort) do
            xml.tag!('sort-key',       key.to_s)
            xml.tag!('sort-direction', direction.to_s.capitalize)
          end
        end
      end
    end

    def Paging(xml)
      return if paging.blank?
      xml.tag!(:RecordOffset,   paging[:offset])   if paging.has_key?(:offset)
      xml.tag!(:RecordsPerPage, paging[:per_page]) if paging.has_key?(:per_page)
    end

    def AdvancedParameters(xml)

    end

    def process_options!
      new_options = (client.default_options[:query] || {}).dup

      (new_options[:flags]      ||= {}).merge!(options[:flags]    || {}).recurse(&:symbolize_keys) if options[:flags].present?
      (new_options[:paging]     ||= {}).merge!(options[:paging]   || {}).recurse(&:symbolize_keys) if options[:paging].present?
      (new_options[:searches]   ||= {}).merge!(options[:searches] || {}).recurse(&:symbolize_keys) if options[:searches].present?
      (new_options[:sorts]      ||= {}).merge!(options[:sorts]    || {}).recurse(&:symbolize_keys) if options[:sorts].present?
      (new_options[:dimensions] = [*new_options[:dimensions]]).concat [*options[:dimensions]]      if options[:dimensions].present?
      new_options[:category]    = options[:category] if options[:category].present?

      @options = new_options
    end

    ##

  end
end
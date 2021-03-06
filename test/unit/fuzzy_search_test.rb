require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

describe "fuzzy_search" do
  before do 
    @kris = create(:person, :last_name => "meier", :first_name => "kristian")
    create(:person, :last_name => "meyer", :first_name => "christian", :hobby => "Bicycling")
    create(:person, :last_name => "mayr", :first_name => "Chris")
    create(:person, :last_name => "maier", :first_name => "christoph", :hobby => "Bicycling")
    create(:person, :last_name => "mueller", :first_name => "andreas")
    create(:person, :last_name => "öther", :first_name => "name")
    create(:person, :last_name => "yet another", :first_name => "name")

    create(:email, :address => "öscar@web.oa")
    create(:email, :address => "david.mike.simon@gmail.com")
    create(:email, :address => "billg@microsoft.com")
  end

  after do
    Person.delete_all
    Email.delete_all
    Person::FuzzySearchTrigram.delete_all
    Email::FuzzySearchTrigram.delete_all
  end

  it "can search for records with similar strings to a query" do
    refute_empty Person.fuzzy_search("maier")
    refute_empty Person.fuzzy_search("ather")
  end
  
  it "can search on multiple columns" do
    result = Person.fuzzy_search("kristin meiar")
    assert_equal "kristian", result[0].first_name
    assert_equal "meier", result[0].last_name
  end

  it "sorts results with the best match first" do
    result = Person.fuzzy_search("kristian meier")
    assert_equal @kris, result.first
    assert result.size > 1
  end

  it "returns an empty result set when given an empty query string" do
    assert_empty Person.fuzzy_search("")
    assert_empty Person.fuzzy_search(nil)
  end

  it "updates the search index automatically when a new record is saved" do
    assert_empty Person.fuzzy_search("David")
    create(:person, :first_name => "David", :last_name => "Simon")
    refute_empty Person.fuzzy_search("David")
  end

  it "only updates the appropriate trigram table" do
    original_state = Email::FuzzySearchTrigram.all.to_a
    create(:person, :first_name => "David", :last_name => "Simon")
    new_state = Email::FuzzySearchTrigram.all.to_a
    assert_equal original_state, new_state
  end

  it "updates the search index automatically when a record is updated" do
    assert_empty Person.fuzzy_search("Obama")
    refute_empty Person.fuzzy_search("yet")

    p = Person.find_by_last_name("yet another")
    p.last_name = "Obama"
    p.save!

    refute_empty Person.fuzzy_search("Obama")
    assert_empty Person.fuzzy_search("yet")
  end

  it "destroys search index entries when a record is destroyed" do
    size = Person.fuzzy_search("other").size
    assert size > 0
    Person.destroy_all(:last_name => "öther")
    assert_equal size, Person.fuzzy_search("other").size + 1
  end

  it "only finds records of the ActiveRecord model you're searching on" do
    refute_empty Person.fuzzy_search("meier")
    assert_empty Email.fuzzy_search("meier")

    assert_empty Person.fuzzy_search("oscar")
    refute_empty Email.fuzzy_search("oscar")
  end

  it "normalizes strings before searching on them" do
    assert_equal 1, Person.fuzzy_search("Müell").size
    assert_equal 1, Email.fuzzy_search("öscar").size
  end

  it "normalizes record strings before indexing them" do
    assert_equal 1, Email.fuzzy_search("oscar").size
  end

  it "can search through a scope" do
    scope = Person.scoped({:conditions => {:hobby => "Bicycling"}})
    full = Person.fuzzy_search("chris")
    subset = scope.fuzzy_search("chris")
    assert full.size > subset.size
    assert subset.size > 0
  end

  it "can use the subset field to narrow the search range" do
    full = Person.fuzzy_search("chris")
    subset = Person.fuzzy_search("chris", :subset => {:favorite_number => 2})
    assert full.size > subset.size
    assert subset.size > 0
  end

  it "can rebuild the search index from scratch" do
    Person::FuzzySearchTrigram.delete_all
    assert_empty Person.fuzzy_search("chris")
    Person.rebuild_fuzzy_search_index!
    refute_empty Person.fuzzy_search("chris")
  end
end

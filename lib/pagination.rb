class Pagination
  attr_reader :items_per_page, :total_items
  attr_accessor :current_page

  def initialize(items_per_page, total_items, current_page)
    @items_per_page = items_per_page
    @total_items = total_items
    @current_page = current_page
  end

  def offset
    start_of_range - 1
  end

  def range
    "#{start_of_range}-#{end_of_range}"
  end

  def prev
    if reached_lower_limit?(current_page - 1)
      "<p class=\"disabled_link\"> &lt; Prev </p>"
    else
      "<a href=\"/books?page=#{current_page - 1}\"> &lt; Prev </a>"
    end
  end

  def next
    if reached_upper_limit?(current_page + 1)
      "<p class=\"disabled_link\"> Next &gt; </p>"
    else
      "<a href=\"/books?page=#{current_page + 1}\"> Next &gt; </a>"
    end
  end
  
  # given the current page number the user is on
  # returns array of page numbers the user
  # can nagivate to -- to be used in pagination
  def nav_pages_array
    if max_pages == 1
      [to_html(1)]
    elsif max_pages == 2
      [to_html(1), to_html(2)]
    elsif reached_upper_limit?(current_page + 1)
      [current_page-2, current_page-1, current_page].map {|p| to_html(p) }
    elsif reached_lower_limit?(current_page - 1)
      [1, 2, 3].map {|p| to_html(p) }
    else
      [ current_page - 1, current_page, current_page + 1].map {|p| to_html(p) }
    end
  end

  def reached_upper_limit?(p = current_page)
    p > max_pages
  end

  def reached_lower_limit?(p = current_page)
    p <= 0
  end

  def max_pages
    (total_items.to_f / items_per_page ).ceil
  end
  
  private

  def start_of_range
    ((current_page - 1) * items_per_page) + 1
  end

  def end_of_range
    [current_page * items_per_page, total_items].min
  end

  def to_html(p)
    "<a href=\"/books?page=#{p}\"> 
      #{p}
    </a> "
  end
end

# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  
  include HtmlCleaner

	# Generates class names for the main div in the application layout
	def classes_for_main
    class_names = controller.controller_name + '-' + controller.action_name
    show_sidebar = ((@user || @admin_posts || @collection || show_wrangling_dashboard) && !@hide_dashboard)
    class_names += " sidebar" if show_sidebar
    class_names
	end

  # A more gracefully degrading link_to_remote.
  def link_to_remote(name, options = {}, html_options = {})
    unless html_options[:href]
      html_options[:href] = url_for(options[:url])
    end
    
    link_to_function(name, remote_function(options), html_options)
  end
  
  def span_if_current(link_to_default_text, path)
    translation_name = "layout.header." + link_to_default_text.gsub(/\s+/, "_")
    link = link_to_unless_current(h(t(translation_name, :default => link_to_default_text)), path)
    current_page?(path) ? "<span class=\"current\">#{link}</span>".html_safe : link
  end
  
  def allowed_html_instructions
    h(t('application_helper.plain_text', :default =>"Plain text with limited html")) + 
    link_to_help("html-help") + 
    "<br /><code>a, abbr, acronym, address, [alt], b, big, blockquote, br, caption, center, cite, [class], code, 
    col, colgroup, datetime, dd, del, dfn, div, dl, dt, em, h1, h2, h3, h4, h5, h6, [height], hr, [href], i, img, 
    ins, kbd, li, name, ol, p, pre, q, samp, small, span, [src], strike, strong, sub, sup, table, tbody, td, 
    tfoot, th, thead, [title], tr, tt, u, ul, var, [width]</code>".html_safe
  end
  
  def allowed_css_instructions
    h(t('application_helper.allowed_css', :default =>"Limited CSS properties and values allowed")) + 
    link_to_help("css-help")
  end
    
  # modified by Enigel Dec 13 08 to use pseud byline rather than just pseud name
  # in order to disambiguate in the case of identical pseuds
  # and on Feb 24 09 to sort alphabetically for great justice
  # and show only the authors when in preview_mode, unless they're empty
  def byline(creation)
    if creation.respond_to?(:anonymous?) && creation.anonymous?
      anon_byline = h(ts("Anonymous"))
      if logged_in_as_admin? || is_author_of?(creation)
        anon_byline += " [".html_safe + non_anonymous_byline(creation) + "]".html_safe
        end
      return anon_byline
    end
    non_anonymous_byline(creation)
  end
      
  def non_anonymous_byline(creation)
    if creation.respond_to?(:author)
      creation.author
    else
      pseuds = []
      pseuds << creation.authors if creation.authors
      pseuds << creation.pseuds if creation.pseuds && (!@preview_mode || creation.authors.blank?)
      pseuds = pseuds.flatten.uniq.sort
    
      archivists = {}
      if creation.is_a?(Work)
        external_creatorships = creation.external_creatorships.select {|ec| !ec.claimed?}
        external_creatorships.each do |ec|
          archivist_pseud = pseuds.select {|p| ec.archivist.pseuds.include?(p)}.first
          archivists[archivist_pseud] = ec.external_author_name.name
        end
      end
    
      pseuds.collect { |pseud| 
        archivists[pseud].nil? ? 
          link_to(pseud.byline, user_pseud_path(pseud.user, pseud), :class => "login author") : 
          archivists[pseud] + 
            t('application_helper.byline.archived_by', :default => "[archived by %{archivist}]", 
              :archivist => link_to(pseud.byline, user_pseud_path(pseud.user, pseud), :class => "login author"))
      }.join(', ').html_safe
    end
  end

  # Currently, help files are static. We may eventually want to make these dynamic? 
  def link_to_help(help_entry, link = '<span class="symbol question"><span>?</span></span>'.html_safe)
    help_file = ""
    #if Locale.active && Locale.active.language
    #  help_file = "#{ArchiveConfig.HELP_DIRECTORY}/#{Locale.active.language.code}/#{help_entry}.html"
    #end
    
    unless !help_file.blank? && File.exists?("#{Rails.root}/public/#{help_file}")
      help_file = "#{ArchiveConfig.HELP_DIRECTORY}/#{help_entry}.html"
    end
    
    link_to_ibox(link, :for => help_file, :title => help_entry.split('-').join(' ').capitalize, :class => "symbol question").html_safe
  end
  
  # Inserts the flash alert messages for flash[:key] wherever 
  #       <%= flash_div :key %> 
  # is placed in the views. That is, if a controller or model sets
  #       flash[:error] = "OMG ERRORZ AIE"
  # or
  #       flash.now[:error] = "OMG ERRORZ AIE"
  #
  # then that error will appear in the view where you have
  #       <%= flash_div :error %>
  #
  # The resulting HTML will look like this:
  #       <div class="flash error">OMG ERRORZ AIE</div>
  #
  # The CSS classes are specified in archive_core.css.
  #
  # You can also have multiple possible flash alerts in a single location with:
  #       <%= flash_div :error, :warning, :notice %>
  # (These are the three varieties currently defined.) 
  #
  def flash_div *keys
    keys.collect { |key| 
      if flash[key] 
        content_tag(:div, h(flash[key]), :class => "flash #{key}") if flash[key] 
      end
    }.join.html_safe
  end

  # Gets an error for a given field if it exists. 
  def flash_field(fieldname)
    if flash[fieldname]
      content_tag(:span, h(flash[fieldname]), :class => "fielderror").html_safe
    end
  end
  
  # For setting the current locale
  def locales_menu    
    result = "<form action=\"" + url_for(:action => 'set', :controller => 'locales') + "\">\n" 
    result << "<div><select id=\"accessible_menu\" name=\"locale_id\" >\n"
    result << options_from_collection_for_select(@loaded_locales, :iso, :name, @current_locale.iso)
    result << "</select></div>"
    result << "<noscript><p><input type=\"submit\" name=\"commit\" value=\"Go\" /></p></noscript>"
    result << "</form>"
    return result
  end  
  
  # Generates sorting links for index pages, with column names and directions
  def sort_link(title, column=nil, options = {})
    condition = options[:unless] if options.has_key?(:unless)

    unless column.nil?
      current_column = (params[:sort_column] == column.to_s) || params[:sort_column].blank? && options[:sort_default]
      css_class = current_column ? "current" : nil
      if current_column # explicitly or implicitly doing the existing sorting, so we need to toggle
        if params[:sort_direction]
          direction = params[:sort_direction].to_s.upcase == 'ASC' ? 'DESC' : 'ASC'
        else 
          direction = options[:desc_default] ? 'ASC' : 'DESC'
        end
      else
        direction = options[:desc_default] ? 'DESC' : 'ASC'
      end
      link_to_unless condition, ((direction == 'ASC' ? '&#8593;<span class="landmark">ascending</span>&#160;' : '&#8595;<span class="landmark">descending</span>&#160;') + title).html_safe, 
          request.parameters.merge( {:sort_column => column, :sort_direction => direction} ), {:class => css_class}
    else
      link_to_unless params[:sort_column].nil?, title, url_for(params.merge :sort_column => nil, :sort_direction => nil)
    end
  end

  ## Allow use of tiny_mce WYSIWYG editor
  def use_tinymce
    @content_for_tinymce = "" 
    content_for :tinymce do
      javascript_include_tag "tiny_mce/tiny_mce"
    end
    @content_for_tinymce_init = "" 
    content_for :tinymce_init do
      javascript_include_tag "mce_editor"
    end
  end  

  def params_without(name)
    params.reject{|k,v| k == name}
  end

  # character counter helpers
  # countdown should count newlines as "\r\n" combos, regardless of the OS and browsers' whim;
  # so we count any single "\n"s and "\r"s as "\r\n", which is what they'd end up as in the db anyway
  def countdown_field(field_id, update_id, max, options = {})
    function = "value = $F('#{field_id}'); value=(value.replace(/\\r\\n/g,'\\n')).replace(/\\r|\\n/g,'\\r\\n'); $('#{update_id}').innerHTML = (#{max} - value.length);"
    count_field_tag(field_id, function, options)
  end
  
  def count_field(field_id, update_id, options = {})
    function = "$('#{update_id}').innerHTML = $F('#{field_id}').length;"
    count_field_tag(field_id, function, options)
  end
  
  def count_field_tag(field_id, function, options = {})  
    out = javascript_tag function
    default_option = {:frequency => 0.25}
    options = default_option.merge(options)
    out += observe_field(field_id, options.merge(:function => function))
    return out
  end
  
  def generate_countdown_html(field_id, max) 
    generated_html = "<p class=\"character_counter\">".html_safe
    generated_html += "<span id=\"#{field_id}_counter\">?</span>".html_safe
    generated_html += countdown_field(field_id, field_id + "_counter", max) + " ".html_safe + h(ts('characters left'))
    generated_html += "</p>".html_safe
    return generated_html
  end
  
  def autocomplete_text_field(fieldname, options={})
    ("\n<span id=\"indicator_#{fieldname}\" style=\"display:none\">" +
    '<img src="/images/spinner.gif" alt="Working..." /></span>' +
    "\n<div class=\"auto_complete\" id=\"#{fieldname}_auto_complete\"></div>").html_safe +
    javascript_tag("new Ajax.Autocompleter('#{fieldname}', 
                            '#{fieldname}_auto_complete', 
                            '/autocomplete/#{options[:methodname].blank? ? fieldname : options[:methodname]}', 
                            { 
                              indicator: 'indicator_#{fieldname}',
                              minChars: #{options[:min_chars] ? options[:min_chars] : '3'},
                              paramName: '#{fieldname}',
                              parameters: 'fieldname=#{fieldname}#{options[:extra_params] ? '&' + options[:extra_params] : ''}',
                              fullSearch: true,
                              tokens: '#{ArchiveConfig.DELIMITER_FOR_INPUT}'
                              #{options[:no_comma] ? '' : ', afterUpdateElement: addCommaToField'}
                              #{options[:auto_params] ? ", autoParams: #{options[:auto_params]}" : ''}
                            });")    
  end
  
  # Trying out a way of sending the tag type to the autocomplete
  # controller so that it can return the right class of results
  def autocomplete_text_field_with_type(object, fieldname, options={})
    ("\n<span id=\"indicator_#{fieldname}\" style=\"display:none\">" +
    '<img src="/images/spinner.gif" alt="Working..." /></span>' +
    "\n<div class=\"auto_complete\" id=\"#{fieldname}_auto_complete\"></div>").html_safe +
    javascript_tag("new Ajax.Autocompleter('#{fieldname}', 
                            '#{fieldname}_auto_complete', 
                            '/autocomplete/#{options[:methodname].blank? ? fieldname : options[:methodname]}', 
                            { 
                              indicator: 'indicator_#{fieldname}',
                              minChars: 2,
                              paramName: '#{fieldname}',
                              parameters: 'fieldname=#{fieldname}&type=#{object.type}',
                              fullSearch: true,
                              tokens: '#{ArchiveConfig.DELIMITER_FOR_INPUT}'
                              #{options[:no_comma] ? '' : ', afterUpdateElement: addCommaToField'}
                            });")    
  end
  
  # see http://asciicasts.com/episodes/197-nested-model-form-part-2
  def link_to_add_section(linktext, form, nested_model_name, partial_to_render, locals = {})
    new_nested_model = form.object.class.reflect_on_association(nested_model_name).klass.new
    child_index = "new_#{nested_model_name}"
    rendered_partial_to_add = 
      form.fields_for(nested_model_name, new_nested_model, :child_index => child_index) {|child_form|
        render(:partial => partial_to_render, :locals => {:form => child_form, :index => child_index}.merge(locals))
      }
    link_to_function(linktext, "add_section(this, \"#{nested_model_name}\", \"#{escape_javascript(rendered_partial_to_add)}\")")
  end

  def link_to_remove_section(linktext, form, class_of_section_to_remove="removeme")
    form.hidden_field(:_destroy) + "\n" +
    link_to_function(linktext, "remove_section(this, \"#{class_of_section_to_remove}\")")
  end
  
  def time_in_zone(time, zone, user=User.current_user)
    time_in_zone = time.in_time_zone(zone)
    time_in_zone_string = time_in_zone.strftime('<abbr class="day" title="%A">%a</abbr> <span class="date">%d</span> 
                                                 <abbr class="month" title="%B">%b</abbr> <span class="year">%Y</span> 
                                                 <span class="time">%I:%M%p</span>').html_safe + 
                                          " <abbr class=\"timezone\" title=\"#{zone}\">#{time_in_zone.zone}</abbr> ".html_safe
    
    user_time_string = "".html_safe
    if user.is_a?(User) && user.preference.time_zone
      if user.preference.time_zone != zone
        user_time = time.in_time_zone(user.preference.time_zone)
        user_time_string = "(".html_safe + user_time.strftime('<span class="time">%I:%M%p</span>').html_safe +
          " <abbr class=\"timezone\" title=\"#{user.preference.time_zone}\">#{user_time.zone}</abbr>)".html_safe
      elsif !user.preference.time_zone
        user_time_string = link_to ts("(set timezone)"), user_preferences_path(user)
      end
    end
    
    time_in_zone_string + user_time_string
  end
  
  def mailto_link(user, options={})
    "<a href=\"mailto:#{h(user.email)}?subject=[#{ArchiveConfig.APP_NAME}]#{options[:subject]}\" class=\"mailto\">
      <img src=\"/images/envelope_icon.gif\" alt=\"#{h(user.login)}'s email\">
    </a>".html_safe
  end
  
end # end of ApplicationHelper

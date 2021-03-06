module ApplicationHelper
  def flash_class(level)
    case level
    when :notice then "info"
    when :error then "error"
    when :alert then "warning"
    end
  end

  def current_theme?(theme)
    (cookies[:theme].blank? and theme == "flatly") or theme == cookies[:theme]
  end

  def twitter_url(twitter_id)
    "https://twitter.com/#{twitter_id}"
  end
end

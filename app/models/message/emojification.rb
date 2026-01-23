module Message::Emojification
  extend ActiveSupport::Concern

  EMOJI_SHORTCODE_PATTERN = /:([a-z0-9_+-]+):/i

  included do
    before_save :emojify_body, if: -> { body.changed? }
  end

  private
    def emojify_body
      return unless body.body.present?

      html = body.body.to_html
      emojified_html = html.gsub(EMOJI_SHORTCODE_PATTERN) do |match|
        shortcode = $1.downcase
        emoji = Emoji.find_by_alias(shortcode)
        emoji ? emoji.raw : match
      end

      self.body = emojified_html if html != emojified_html
    end
end

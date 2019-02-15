begin
  require 'easy_translate'
rescue Exception => exc
  CommonDialogs.showError("Error resolving dependency 'easy_translate'.  Did you install the Ruby gem?")
  exit 1
end
require 'json'

# hash of languages
# { "en" => "english" }
@langs = EasyTranslate::LANGUAGES
@script_directory = File.dirname(__FILE__)
# Load settings
@settings =
  if File.exist?(File.join(@script_directory, 'settings.json'))
    JSON.parse(File.read(File.join(@script_directory, 'settings.json')))
  else
    { 'googleTranslateApiKey' => '',
      'customMetadataFieldName' => 'Detected Languages',
      'defaultLanguage' => 'english',
      'topLevelTag' => 'Detected Languages' }
  end
# Nx
begin
  require File.join(@script_directory, 'Nx.jar')
  java_import 'com.nuix.nx.NuixConnection'
  java_import 'com.nuix.nx.LookAndFeelHelper'
  java_import 'com.nuix.nx.dialogs.CommonDialogs'
  java_import 'com.nuix.nx.dialogs.ProgressDialog'
  java_import 'com.nuix.nx.dialogs.TabbedCustomDialog'
  LookAndFeelHelper.setWindowsIfMetal
  NuixConnection.setUtilities($utilities)
  NuixConnection.setCurrentNuixVersion(NUIX_VERSION)
end

# Updates an item's text to remove a translation.
#
# @param item [Item] a Nuix item
def clear_translation(item)
  newtxt = get_text(item.getTextObject.toString)
  return nil if newtxt.empty?

  item.modify { |modifier| modifier.replace_text(newtxt[1]) }
end

# Annotates item with detected language.
#
# @param item [Item] a Nuix item
# @param apply_custom_metadata [Boolean] to apply custom metadata
# @param tag_item [Boolean] to tag item
def detect(item, apply_custom_metadata, tag_item)
  langs = detect_language(item)
  return nil if langs.nil?

  language = "#{@langs[langs].capitalize} (#{langs})"
  item.getCustomMetadata.putText(@settings['customMetadataFieldName'], language) if apply_custom_metadata
  item.addTag("#{@settings['topLevelTag']}|#{language}") if tag_item
end

# Detects an item's lnaguage using EasyTranslate.
#
# @param item [Item] a Nuix item
# @return [String, nil] of detected language from Google, or nil
#  if no text or language detected
def detect_language(item)
  txt = get_text(item)
  return nil if txt.empty?

  langs = EasyTranslate.detect(txt).to_s
  # Google returns "und" (undefined) if the language has not been detected
  return nil if langs.eql?('und')

  langs
end

# Returns enabled options Hash.
#
# @param operation [String] the operation
# @return [Hash] emnabled operations
# @option enabled [Boolean] :translation
# @option enabled [Boolean] :detection
def get_options_enabled(operation)
  enabled = {}
  case operation.downcase!
  when 'detect languages'
    enabled[:translation] = false
    enabled[:detection] = true
  when 'translate text'
    enabled[:translation] = true
    enabled[:detection] = false
  when 'detect languages and translate text'
    enabled[:translation] = true
    enabled[:detection] = true
  when 'clear translations'
    enabled[:translation] = false
    enabled[:detection] = false
  end
  enabled
end

# Returns original text if it had been translated.
#
# @param text [String]
# @return [String] of text, to the left of ---Tran if matched
def get_text(text)
  mymatch = /(^.*?)\n---+Tran/m.match(text)
  return mymatch[1] unless mymatch.nil?

  text
end

# Returns new text with translation appended.
#
# @param text [String] original text
# @param target [String] target language
# @param translated [String] translated text
# @return [String] of new text
def get_new_text(original, target, translated)
  original + "\n----------Translation to #{target}----------\n" + translated
end

# Translates and updates and item's text.
#
# @param item [Item] a Nuix item
# @param target [String] target language
def translate(item, target)
  text = item.getTextObject.toString
  txt = get_text(text)
  return nil if txt.empty?

  transed = EasyTranslate.translate(txt, format: 'text', to: @langs.key(target))
  return nil if transed.empty?

  item.modify { |m| m.replace_text(get_new_text(text, target, transed)) }
end

# Saves settings.
def save_settings
  File.open(File.join(@script_directory, 'settings.json'), 'w') do |file|
    file.write(JSON.pretty_generate(@settings))
  end
end

# Set enabled state of options.
#
# @param main_tab [Tab] main tab fromTabbedCustomDialog
def set_options_enabled(main_tab)
  enabled = get_options_enabled(main_tab.getText('translation_operation'))
  main_tab.getControl('translation_language').setEnabled(enabled[:translation])
  main_tab.getControl('save_translation_lang').setEnabled(enabled[:translation])
  main_tab.getControl('apply_custom_metadata').setEnabled(enabled[:detection])
  main_tab.getControl('custom_metadata_field_name').setEnabled(enabled[:detection] && main_tab.isChecked('apply_custom_metadata'))
  main_tab.getControl('tag_items').setEnabled(enabled[:detection])
  main_tab.getControl('top_level_tag').setEnabled(enabled[:detection] && main_tab.isChecked('tag_items'))
end

begin
  # Setup the dialog
  dialog = TabbedCustomDialog.new('Language Translation')

  main_tab = dialog.addTab('main_tab', 'Translation')

  translation_options = [
    'Detect languages',
    'Translate text',
    'Detect languages and translate text',
    'Clear translations'
  ]

  main_tab.appendTextField('google_translate_api_key', 'Google Translate API Key', @settings['googleTranslateApiKey'])
  main_tab.appendComboBox('translation_operation', 'Translation operation', translation_options)
  # Detection Options
  main_tab.appendSeparator('Detection Options')
  main_tab.appendCheckBox('apply_custom_metadata', 'Apply detected language as custom metadata?', false)
  main_tab.appendTextField('custom_metadata_field_name', 'Custom Metadata Field Name', @settings['customMetadataFieldName'])
  main_tab.appendCheckBox('tag_items', 'Tag items with detected language?', false)
  main_tab.appendTextField('top_level_tag', 'Top-level tag', @settings['topLevelTag'])
  main_tab.enabledOnlyWhenChecked('custom_metadata_field_name', 'apply_custom_metadata')
  main_tab.enabledOnlyWhenChecked('top_level_tag', 'tag_items')
  # Translation Options
  main_tab.appendSeparator('Translation Options')
  main_tab.appendComboBox('translation_language', 'Translation language', @langs.values)
  main_tab.appendCheckBox('save_translation_lang', 'Save as default translation language', false)

  # Set default language
  main_tab.getControl('translation_language').setSelectedItem(@settings['defaultLanguage'])

  # Update translation language enabled state when translation operation changes
  main_tab.getControl('translation_operation').addActionListener do
    set_options_enabled(main_tab)
  end

  # disable the translation options by default
  set_options_enabled(main_tab)

  # Validation
  dialog.validateBeforeClosing do |values|
    if values['google_translate_api_key'].strip.empty?
      CommonDialogs.showWarning('Please provide a Google Translate API Key.')
      next false
    end

    if values['apply_custom_metadata'] && values['custom_metadata_field_name'].strip.empty?
      CommonDialogs.showWarning('Please provide a Custom Metadata Field Name.')
      next false
    end

    if values['tag_items'] && values['top_level_tag'].strip.empty?
      CommonDialogs.showWarning('Please provide a Top-level tag.')
      next false
    end

    next true
  end

  dialog.display

  if dialog.getDialogResult
    input = dialog.toMap

    annotate_items = false
    tag_items = false
    # update settings
    @settings['googleTranslateApiKey'] = input['google_translate_api_key'].strip
    if input['save_translation_lang']
      @settings['defaultLanguage'] = input['translation_language']
    end

    if input['apply_custom_metadata']
      @settings['customMetadataFieldName'] = input['custom_metadata_field_name'].strip
      annotate_items = true
    end

    if input['tag_items']
      @settings['topLevelTag'] = input['top_level_tag'].strip
      tag_items = true
    end

    EasyTranslate.api_key = @settings['googleTranslateApiKey']

    items = $current_selected_items
    operation = main_tab.getText('translation_operation')

    ProgressDialog.forBlock do |pd|
      pd.setTitle(operation)
      main_progress = 0
      pd.setMainProgress(main_progress, items.size)
      pd.setMainProgressVisible(true)
      pd.setSubProgressVisible(false)

      # Ensure proper logging
      pd.onMessageLogged do |message|
        puts message
      end

      $current_case.with_write_access do
        items.each_with_index do |item, _index|
          break if pd.abortWasRequested

          main_progress += 1
          pd.setMainProgress(main_progress)
          pd.setSubStatus("Item #{main_progress}/#{items.size}")

          case operation
          when 'Detect languages'
            pd.setMainStatus('Detecting Languages')
            pd.logMessage("Detecting language (#{main_progress}/#{items.size}): [Item GUID: #{item.getGuid}]")
            detect(item, annotate_items, tag_items)
          when 'Translate text'
            pd.setMainStatus('Translating')
            pd.logMessage("Translating text (#{main_progress}/#{items.size}): [Item GUID: #{item.getGuid}]")
            translate(item, input['translation_language'])
          when 'Detect languages and translate text'
            pd.setMainStatus('Detecting Languages')
            pd.logMessage("Detecting language (#{main_progress}/#{items.size}): [Item GUID: #{item.getGuid}]")
            detect(item, annotate_items, tag_items)

            pd.setMainStatus('Translating')
            pd.logMessage("Translating text (#{main_progress}/#{items.size}): [Item GUID: #{item.getGuid}]")
            translate(item, input['translation_language'])
          when 'Clear translations'
            pd.logMessage("Clearing translation (#{main_progress}/#{items.size}): [Item GUID: #{item.getGuid}]")
            clear_translation(item)
          end
        end
      end

      pd.logMessage('Aborting...') if pd.abortWasRequested
      pd.logMessage('Completed!')
    end

    # save settings
    save_settings
  end
end

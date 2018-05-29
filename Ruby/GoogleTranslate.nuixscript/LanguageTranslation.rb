@script_directory = File.dirname(__FILE__)
require File.join(@script_directory, "Nx.jar")

java_import "com.nuix.nx.NuixConnection"
java_import "com.nuix.nx.LookAndFeelHelper"
java_import "com.nuix.nx.dialogs.CommonDialogs"
java_import "com.nuix.nx.dialogs.ProgressDialog"
java_import "com.nuix.nx.dialogs.TabbedCustomDialog"

LookAndFeelHelper.setWindowsIfMetal
NuixConnection.setUtilities($utilities)
NuixConnection.setCurrentNuixVersion(NUIX_VERSION)

begin
	require 'easy_translate'
rescue Exception => exc
	CommonDialogs.showError("Error resolving dependency 'easy_translate'.  Did you install the Ruby gem?")
	exit 1
end

require 'json'

# hash of languages
# { "en" => "english" }
@langs =  EasyTranslate::LANGUAGES

# Load settings
@settings =
if File.exist?(File.join(@script_directory, "settings.json"))
	JSON.parse(File.read(File.join(@script_directory, "settings.json")))
else
	{"googleTranslateApiKey" => "",
	"customMetadataFieldName" => "Detected Languages",
	"defaultLanguage" => "english",
	"topLevelTag" => "Detected Languages"}
end

# Setup the dialog
dialog = TabbedCustomDialog.new("Language Translation")

main_tab = dialog.addTab("main_tab", "Translation")

translation_options = [
	"Detect languages",
	"Translate text",
	"Detect languages and translate text",
	"Clear translations"
]

main_tab.appendTextField("google_translate_api_key", "Google Translate API Key", @settings["googleTranslateApiKey"])
main_tab.appendComboBox("translation_operation", "Translation operation", translation_options)

main_tab.appendSeparator("Detection Options")
main_tab.appendCheckBox("apply_custom_metadata", "Apply detected language as custom metadata?", false)
main_tab.appendTextField("custom_metadata_field_name", "Custom Metadata Field Name", @settings["customMetadataFieldName"])
main_tab.appendCheckBox("tag_items", "Tag items with detected language?", false)
main_tab.appendTextField("top_level_tag", "Top-level tag", @settings["topLevelTag"])
main_tab.enabledOnlyWhenChecked("custom_metadata_field_name", "apply_custom_metadata")
main_tab.enabledOnlyWhenChecked("top_level_tag", "tag_items")

main_tab.appendSeparator("Translation Options")
main_tab.appendComboBox("translation_language", "Translation language", @langs.values)
main_tab.appendCheckBox("save_translation_lang", "Save as default translation language", false)

# Set default language
main_tab.getControl("translation_language").setSelectedItem(@settings["defaultLanguage"])

# Set enabled state of options
def set_options_enabled(main_tab)
	operation = main_tab.getText("translation_operation")
	
	translation_options_enabled = false
	detection_options_enabled = false
	
	case operation.downcase!
	when "detect languages"
		translation_options_enabled = false
		detection_options_enabled = true
	when "translate text"
		translation_options_enabled = true
		detection_options_enabled = false
	when "detect languages and translate text"
		translation_options_enabled = true
		detection_options_enabled = true
	when "clear translations"
		translation_options_enabled = false
		detection_options_enabled = false
	end
	
	main_tab.getControl("translation_language").setEnabled(translation_options_enabled)
	main_tab.getControl("save_translation_lang").setEnabled(translation_options_enabled)
	
	main_tab.getControl("apply_custom_metadata").setEnabled(detection_options_enabled)
	main_tab.getControl("custom_metadata_field_name").setEnabled(detection_options_enabled && main_tab.isChecked("apply_custom_metadata"))
	main_tab.getControl("tag_items").setEnabled(detection_options_enabled)
	main_tab.getControl("top_level_tag").setEnabled(detection_options_enabled && main_tab.isChecked("tag_items"))
end

# Update translation language enabled state when translation operation changes
main_tab.getControl("translation_operation").addActionListener do
	set_options_enabled(main_tab)
end

# disable the translation options by default
set_options_enabled(main_tab)

def detect(item, apply_custom_metadata, tag_item)
	mymatch = /(^.*?)\n---+Tran/m.match(item.getTextObject.toString)
	txt = item.getTextObject.toString
	txt = mymatch[1] if not mymatch.nil?
	langs = EasyTranslate.detect(txt).to_s
	language = "#{@langs[langs].capitalize} (#{langs})"
	if(apply_custom_metadata)
		item.getCustomMetadata().putText(@settings["customMetadataFieldName"], language)
	end
	
	if(tag_item)
		item.addTag("#{@settings["topLevelTag"]}|#{language}")
	end
end

def translate(item, target_language)
	mymatch =  /(^.*?)\n---+Tran/m.match(item.getTextObject.toString)
	txt = item.getTextObject.toString
	txt = mymatch[1] if not mymatch.nil?
	
	translated = EasyTranslate.translate(txt, :format => 'text', :to => @langs.key(target_language) )
	newtext = item.getTextObject.toString + "\n----------Translation to #{target_language}----------\n" + translated
	item.modify { |modifier| modifier.replace_text(newtext) }
end

def clear_translation(item)
	txt = item.getTextObject.toString
	newtxt  =  /(^.*?)\n---+Tran/m.match(txt)
	return if newtxt.nil?
	replace = newtxt[1]

	item.modify { |modifier| modifier.replace_text(replace) }
end

def save_settings
	File.open(File.join(@script_directory,"settings.json"), "w") do |file|
		file.write(JSON.pretty_generate(@settings))
	end
end

# Validation
dialog.validateBeforeClosing do |values|
	if values["google_translate_api_key"].strip.empty?
		CommonDialogs.showWarning("Please provide a Google Translate API Key.")
		next false
	end
	
	if values["apply_custom_metadata"] && values["custom_metadata_field_name"].strip.empty?
		CommonDialogs.showWarning("Please provide a Custom Metadata Field Name.")
		next false
	end
	
	if values["tag_items"] && values["top_level_tag"].strip.empty?
		CommonDialogs.showWarning("Please provide a Top-level tag.")
		next false
	end
	
	next true
end

dialog.display

if dialog.getDialogResult
	input = dialog.toMap
	
	annotateItems = false
	tagItems = false
	# update settings
	@settings["googleTranslateApiKey"] = input["google_translate_api_key"].strip
	if(input["save_translation_lang"])
		@settings["defaultLanguage"] = input["translation_language"]
	end
	
	if(input["apply_custom_metadata"])
		@settings["customMetadataFieldName"] = input["custom_metadata_field_name"].strip
		annotateItems = true
	end
	
	if(input["tag_items"])
		@settings["topLevelTag"] = input["top_level_tag"].strip
		tagItems = true
	end
	
	EasyTranslate.api_key = @settings["googleTranslateApiKey"]
	
	items = $current_selected_items
	operation = main_tab.getText("translation_operation")

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
			items.each_with_index do |item, index|
				break if pd.abortWasRequested
				
				main_progress += 1
				pd.setMainProgress(main_progress)
				pd.setSubStatus("Item #{main_progress}/#{items.size}")
				
				case operation
					when "Detect languages"
						pd.setMainStatus("Detecting Languages")
						pd.logMessage("Detecting language (#{main_progress}/#{items.size}): [Item GUID: #{item.getGuid}]")
						detect(item, annotateItems, tagItems)
					when "Translate text"
						pd.setMainStatus("Translating")
						pd.logMessage("Translating text (#{main_progress}/#{items.size}): [Item GUID: #{item.getGuid}]")
						translate(item, input["translation_language"])
					when "Detect languages and translate text"
						pd.setMainStatus("Detecting Languages")
						pd.logMessage("Detecting language (#{main_progress}/#{items.size}): [Item GUID: #{item.getGuid}]")
						detect(item, annotateItems, tagItems)
						
						pd.setMainStatus("Translating")
						pd.logMessage("Translating text (#{main_progress}/#{items.size}): [Item GUID: #{item.getGuid}]")
						translate(item, input["translation_language"])
					when "Clear translations"
						pd.logMessage("Clearing translation (#{main_progress}/#{items.size}): [Item GUID: #{item.getGuid}]")
						clear_translation(item)
				end
			end
		end
		
		if pd.abortWasRequested
			pd.logMessage("Aborting...")
		end
		
		pd.logMessage("Completed!")
	end
	
	# save settings
	save_settings
end
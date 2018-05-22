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
	{"googleTranslateApiKey" => "", "defaultLanguage" => "english"}
end

# Setup the dialog
dialog = TabbedCustomDialog.new("Language Translation")

main_tab = dialog.addTab("main_tab", "Translation")

translation_options = [
	"Detect languages",
	"Translate text",
	"Clear translations"
]

main_tab.appendTextField("google_translate_api_key", "Google Translate API Key", @settings["googleTranslateApiKey"])
main_tab.appendComboBox("translation_operation", "Translation operation", translation_options)
main_tab.appendSeparator("Translation Options")
main_tab.appendComboBox("translation_language", "Translation language", @langs.values)
main_tab.appendCheckBox("save_translation_lang", "Save as default translation language", false)

# Set default language
main_tab.getControl("translation_language").setSelectedItem(@settings["defaultLanguage"])

# Set enabled state of Translation options
def set_translation_options_enabled(enabled, main_tab)
	main_tab.getControl("translation_language").setEnabled(enabled)
	main_tab.getControl("save_translation_lang").setEnabled(enabled)
end

# Update translation language enabled state when translation operation changes
main_tab.getControl("translation_operation").addActionListener do
	operation = main_tab.getText("translation_operation")
	set_translation_options_enabled(operation.eql?("Translate text"), main_tab)
end

# disable the translation options by default
set_translation_options_enabled(false, main_tab)

def detect(item)
	mymatch =  /(^.*?)\n---+Tran/m.match(item.getTextObject.toString)
	txt = item.getTextObject.toString
	txt = mymatch[1] if not mymatch.nil?
	langs = EasyTranslate.detect(txt).to_s
	language = "#{@langs[langs].capitalize} (#{langs})"
	item.getCustomMetadata().putText("Detected Languages", language)
	item.addTag("Detected Languages|#{language}")
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
	
	next true
end

dialog.display

if dialog.getDialogResult
	input = dialog.toMap
	
	EasyTranslate.api_key = input["google_translate_api_key"].strip
	
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
						detect(item)
					when "Translate text"
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
		
		# update and save settings
		@settings["googleTranslateApiKey"] = input["google_translate_api_key"].strip
		if(input["save_translation_lang"])
			@settings["defaultLanguage"] = input["translation_language"]
		end
		save_settings
		
		pd.logMessage("Completed!")
	end
end
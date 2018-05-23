
Language Translation
====================

![Last tested in Nuix 7.4](https://img.shields.io/badge/Nuix-7.4-green.svg)

View the GitHub project [here](https://github.com/Nuix/Language-Translation) or download the latest release [here](https://github.com/Nuix/Language-Translation/releases).

## Overview
The Language Translation script will translate the text of items into another language. The script can also detect the language of the text and clear translated text.

## Prerequisites
### Google Cloud Translation API Access
You will need a Google Cloud Platform account to access the Google Cloud Translation API. Use the following steps to sign up for an account.
1. Sign up for an account here, https://cloud.google.com/translate/
2. From the [Google Cloud Platform Console](https://console.cloud.google.com/home) select `APIs & Services`
3. From the [API Dashboard](https://console.cloud.google.com/apis/dashboard) select `Enable APIs and Services`
4. Search for and enable the `Google Cloud Translation API`
5. On the [Google Cloud Translation API overview](https://console.cloud.google.com/apis/api/translate.googleapis.com/overview) select `Credentials`
6. Click `Create credentials` and select `API Key`
7. Copy the API key provided

### Easy Translate Gem
The script makes use of a RubyGem which must be installed using the following command run via Command Prompt from your Nuix Workstation installation directory

`c:\Program Files\Nuix\Nuix 7.4>jre\bin\java -Xmx500M -classpath lib\* org.jruby.Main --command gem install easy_translate --user-install`

## Setup

Begin by downloading the latest release.  Extract the contents of the archive into your Nuix scripts directory.  In Windows the script directory is likely going to be either of the following:

- `%appdata%\Nuix\Scripts` - User level script directory
- `%programdata%\Nuix\Scripts` - System level script directory

## Settings
### Translation Tab
Setting | Description
------- | -----------
**Google Translate API Key** | API Key provided by Google. The API Key is saved in the `settings.json` file located in the script directory and used to populate the field the next time the script is run
**Translation operation** | Select the operation you would like to perform
**Translation language\*** | Select the target translation language
**Save as default translation language\*** | Optionally saves the selected Translation language as the default

\* - Available when `Translate text` Translation option is selected

Translation operation | Description
--------------------- | ------------
**Detect languages** | Detects the language of selected items and saves results in the item's custom metadata
**Translate text** | Translates the text of selected items. Translated text is stored in the item's text object
**Clear translations** | Removes the translated text from the item's text object. Item's original text will remain

# License

```
Copyright 2018 Nuix

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

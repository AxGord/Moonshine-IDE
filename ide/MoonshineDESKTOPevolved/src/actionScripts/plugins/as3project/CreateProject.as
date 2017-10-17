////////////////////////////////////////////////////////////////////////////////
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
// http://www.apache.org/licenses/LICENSE-2.0 
// 
// Unless required by applicable law or agreed to in writing, software 
// distributed under the License is distributed on an "AS IS" BASIS, 
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and 
// limitations under the License
// 
// No warranty of merchantability or fitness of any kind. 
// Use this software at your own risk.
// 
////////////////////////////////////////////////////////////////////////////////
package actionScripts.plugins.as3project
{
    import flash.display.DisplayObject;
    import flash.events.Event;
    import flash.filesystem.File;
    import flash.net.SharedObject;
    
    import mx.collections.ArrayCollection;
    
    import actionScripts.events.AddTabEvent;
    import actionScripts.events.GlobalEventDispatcher;
    import actionScripts.events.NewProjectEvent;
    import actionScripts.events.OpenFileEvent;
    import actionScripts.events.ProjectEvent;
    import actionScripts.factory.FileLocation;
    import actionScripts.locator.IDEModel;
    import actionScripts.plugin.actionscript.as3project.settings.NewProjectSourcePathListSetting;
    import actionScripts.plugin.actionscript.as3project.vo.AS3ProjectVO;
    import actionScripts.plugin.settings.SettingsView;
    import actionScripts.plugin.settings.vo.BooleanSetting;
    import actionScripts.plugin.settings.vo.ISetting;
    import actionScripts.plugin.settings.vo.ListSetting;
    import actionScripts.plugin.settings.vo.MultiOptionSetting;
    import actionScripts.plugin.settings.vo.NameValuePair;
    import actionScripts.plugin.settings.vo.PathSetting;
    import actionScripts.plugin.settings.vo.SettingsWrapper;
    import actionScripts.plugin.settings.vo.StaticLabelSetting;
    import actionScripts.plugin.settings.vo.StringSetting;
    import actionScripts.plugin.templating.TemplatingHelper;
    import actionScripts.plugins.as3project.exporter.FlashDevelopExporter;
    import actionScripts.plugins.as3project.importer.FlashDevelopImporter;
    import actionScripts.ui.tabview.CloseTabEvent;
    import actionScripts.plugin.project.ProjectTemplateType;
    import actionScripts.plugin.project.ProjectType;
    import actionScripts.utils.SDKUtils;
    import actionScripts.valueObjects.ConstantsCoreVO;
    import actionScripts.valueObjects.TemplateVO;
	
	public class CreateProject
	{
		public var activeType:uint = ProjectType.AS3PROJ_AS_AIR;
		
		private var newProjectSourcePathSetting:NewProjectSourcePathListSetting;
		private var newProjectNameSetting:StringSetting;
		private var newProjectPathSetting:PathSetting;
		private var newProjectTypeSetting:MultiOptionSetting;
		private var cookie:SharedObject;
		private var templateLookup:Object = {};
		private var project:AS3ProjectVO;
		private var allProjectTemplates:ArrayCollection;
		private var model:IDEModel = IDEModel.getInstance();
		
		private var isActionScriptProject:Boolean;
		private var isMobileProject:Boolean;
		private var isOpenProjectCall:Boolean;
		private var isFeathersProject:Boolean;
		private var isVisualEditorProject:Boolean;
		private var isAway3DProject:Boolean;
		
		private var _isProjectFromExistingSource:Boolean;
		private var _projectTemplateType:String;
		private var _customFlexSDK:String;
		
		public function CreateProject(event:NewProjectEvent)
		{
			if (!allProjectTemplates)
			{
				allProjectTemplates = new ArrayCollection();
				allProjectTemplates.addAll(ConstantsCoreVO.TEMPLATES_PROJECTS);
				allProjectTemplates.addAll(ConstantsCoreVO.TEMPLATES_PROJECTS_SPECIALS);
			}
			
			if (isAllowedTemplateFile(event.projectFileEnding))
			{
				createAS3Project(event);
            }
			else if (event.projectFileEnding == "awd")
			{
				createAway3DProject(event);
            }
		}
		
		public function get isProjectFromExistingSource():Boolean
		{
			return _isProjectFromExistingSource;
		}
		
		public function set isProjectFromExistingSource(value:Boolean):void
		{
			_isProjectFromExistingSource = project.isProjectFromExistingSource = value;
			if (_isProjectFromExistingSource)
			{
				///project.projectFolder = null;
				project.projectName = newProjectNameSetting.stringValue;
				project.folderLocation = new FileLocation(newProjectPathSetting.stringValue);
				
				newProjectSourcePathSetting.project = project;
				newProjectPathSetting.addEventListener(PathSetting.PATH_SELECTED, onProjectPathChanged);
			}
			else
			{
				newProjectPathSetting.removeEventListener(PathSetting.PATH_SELECTED, onProjectPathChanged);
			}
			
			newProjectSourcePathSetting.visible = _isProjectFromExistingSource;
			/*newProjectNameSetting.isEditable = newProjectPathSetting.isEditable = !_isProjectFromExistingSource;
			if (newProjectTypeSetting) newProjectTypeSetting.isEditable = !_isProjectFromExistingSource;*/
		}
		
		public function set projectTemplateType(value:String):void
		{
			_projectTemplateType = value;
		}
		public function get projectTemplateType():String
		{
			return _projectTemplateType;
		}
		
		public function get customFlexSDK():String
		{
			return _customFlexSDK;
		}
		public function set customFlexSDK(value:String):void
		{
			_customFlexSDK = value;
		}
		
		private function createAS3Project(event:NewProjectEvent):void
		{
			// Only template for those we can handle
			if (!isAllowedTemplateFile(event.projectFileEnding)) return;

            setProjectType(event.templateDir.fileBridge.name);

            cookie = SharedObject.getLocal("moonshine-ide-local");
			//Read recent project path from shared object
			
			// if opened by Open project, event.settingsFile will be false
			// and event.templateDir will be open folder location
			isOpenProjectCall = !event.settingsFile;

			if (isOpenProjectCall)
			{
				project = new AS3ProjectVO(event.templateDir, null, false);
			}
			else
			{
				project = FlashDevelopImporter.parse(event.settingsFile, null, null, false);
			}
			
			project.isVisualEditorProject = isVisualEditorProject;

			if (cookie.data.hasOwnProperty('recentProjectPath'))
			{
				model.recentSaveProjectPath.source = cookie.data.recentProjectPath;
			}
			else
			{
				project.folderLocation = new FileLocation(File.documentsDirectory.nativePath);
				if (!model.recentSaveProjectPath.contains(project.folderLocation.fileBridge.nativePath)) model.recentSaveProjectPath.addItem(project.folderLocation.fileBridge.nativePath);
			}
			
			// remove any ( or ) stuff
			if (!isOpenProjectCall)
			{
				var tempName: String = event.templateDir.fileBridge.name.substr(0, event.templateDir.fileBridge.name.indexOf("("));
				if (event.templateDir.fileBridge.name.indexOf("FlexJS") != -1)
				{
					project.projectName = "NewFlexJSBrowserProject";
                }
				else
				{
					project.projectName = event.exportProject ? event.exportProject.name : "New"+tempName;
                }
			}
			
			if (isOpenProjectCall)
			{
				if (!model.recentSaveProjectPath.contains(event.templateDir.fileBridge.nativePath))
				{
					model.recentSaveProjectPath.addItem(event.templateDir.fileBridge.nativePath);
                }
				project.projectName = "ExternalProject";
				project.isProjectFromExistingSource = true;
			}
				
			project.folderLocation = new FileLocation(model.recentSaveProjectPath.source[model.recentSaveProjectPath.length - 1]);
			
			var settingsView:SettingsView = new SettingsView();
			settingsView.exportProject = event.exportProject;
			settingsView.Width = 150;
			settingsView.defaultSaveLabel = event.isExport ? "Export" : "Create";
			settingsView.isNewProjectSettings = true;
			
			settingsView.addCategory("");
			// Remove spaces from project name
			project.projectName = project.projectName.replace(/ /g, "");
			
			var nvps:Vector.<NameValuePair> = Vector.<NameValuePair>([
				new NameValuePair("AIR", ProjectType.AS3PROJ_AS_AIR),
				new NameValuePair("Web", ProjectType.AS3PROJ_AS_WEB),
			    new NameValuePair("Visual Editor", ProjectType.VISUAL_EDITOR)
			]);

			var settings:SettingsWrapper = getProjectSettings(project, event);

			if (newProjectSourcePathSetting)
            {
                if (isOpenProjectCall)
                {
                    isProjectFromExistingSource = project.isProjectFromExistingSource;
                }

                newProjectSourcePathSetting.visible = project.isProjectFromExistingSource;
            }
			
            if (isActionScriptProject)
			{
				isActionScriptProject = true;
				newProjectTypeSetting = new MultiOptionSetting(this, "activeType", "Select project type", nvps);
				settings.getSettingsList().splice(4, 0, newProjectTypeSetting);
			}

			if (isOpenProjectCall)
			{
				settings.getSettingsList().splice(3, 0, new ListSetting(this, "projectTemplateType", "Select Template Type", allProjectTemplates, "title"));
			}
			
			settingsView.addEventListener(SettingsView.EVENT_SAVE, createSave);
			settingsView.addEventListener(SettingsView.EVENT_CLOSE, createClose);
			settingsView.addSetting(settings, "");
			
			settingsView.label = "New Project";
			settingsView.associatedData = project;
			
			GlobalEventDispatcher.getInstance().dispatchEvent(
				new AddTabEvent(settingsView)
			);
			
			templateLookup[project] = event.templateDir;
		}
		
		private function createAway3DProject(event:NewProjectEvent):void
		{
			project = new AS3ProjectVO(model.fileCore.resolveDocumentDirectoryPath(), null, false);
			cookie = SharedObject.getLocal("moonshine-ide-local");
			
			if (cookie.data.hasOwnProperty('recentProjectPath'))
			{
				model.recentSaveProjectPath.source = cookie.data.recentProjectPath;
			}
			else
			{
				if (!model.recentSaveProjectPath.contains(project.folderLocation.fileBridge.nativePath)) model.recentSaveProjectPath.addItem(project.folderLocation.fileBridge.nativePath);
			}
			
			project.folderLocation = new FileLocation(model.recentSaveProjectPath.source[model.recentSaveProjectPath.length - 1]);
			
			var settingsView:SettingsView = new SettingsView();
			settingsView.Width = 150;
			settingsView.defaultSaveLabel = "Create";
			settingsView.isNewProjectSettings = true;
			
			settingsView.addCategory("");
			
			var settings:SettingsWrapper = getProjectSettings(project, event);
			
			settingsView.addEventListener(SettingsView.EVENT_SAVE, createSave);
			settingsView.addEventListener(SettingsView.EVENT_CLOSE, createClose);
			settingsView.addSetting(settings, "");
			
			settingsView.label = "New Project";
			settingsView.associatedData = project;
			
			GlobalEventDispatcher.getInstance().dispatchEvent(
				new AddTabEvent(settingsView)
			);
			
			templateLookup[project] = event.templateDir;
		}

        private function isAllowedTemplateFile(projectFileExtension:String):Boolean
        {
            return projectFileExtension != "as3proj" || projectFileExtension != "veditorproj";
        }

		private function getProjectSettings(project:AS3ProjectVO, eventObject:NewProjectEvent):SettingsWrapper
		{
            newProjectNameSetting = new StringSetting(project, 'projectName', 'Project name', 'a-zA-Z0-9._');
            newProjectPathSetting = new PathSetting(project, 'folderPath', 'Project directory', true, null, false, true);

			if (eventObject.isExport)
			{
				newProjectNameSetting.isEditable = false;
                return new SettingsWrapper("Name & Location", Vector.<ISetting>([
                    new StaticLabelSetting('New ' + eventObject.templateDir.fileBridge.name),
                    newProjectNameSetting, // No space input either plx
                    newProjectPathSetting
                ]));
			}

			if (eventObject.projectFileEnding == "awd")
            {
                return new SettingsWrapper("Name & Location", Vector.<ISetting>([
                    new StaticLabelSetting('New Away3D Project'),
                    new StringSetting(project, 'projectName', 'Project name', 'a-zA-Z0-9._'),
                    new PathSetting(project, 'folderPath', 'Project directory', true, null, false, true)
                ]));
            }

            newProjectSourcePathSetting = new NewProjectSourcePathListSetting(project,
					"projectWithExistingSourcePaths", "Main source folder");
			
            if (project.isVisualEditorProject && !eventObject.isExport)
            {
                return new SettingsWrapper("Name & Location", Vector.<ISetting>([
                    new StaticLabelSetting('New ' + eventObject.templateDir.fileBridge.name),
                    newProjectNameSetting, // No space input either plx
                    newProjectPathSetting,
                    new BooleanSetting(this, "isProjectFromExistingSource", "Project with existing source", true),
                    newProjectSourcePathSetting
                ]));
            }

            return new SettingsWrapper("Name & Location", Vector.<ISetting>([
				new StaticLabelSetting('New '+ eventObject.templateDir.fileBridge.name),
				newProjectNameSetting, // No space input either plx
				newProjectPathSetting,
				new PathSetting(this,'customFlexSDK', 'Apache Flex® or FlexJS® SDK', true, customFlexSDK, true),
				new BooleanSetting(this, "isProjectFromExistingSource", "Project with existing source", true),
				newProjectSourcePathSetting
			]));
		}

		//--------------------------------------------------------------------------
		//
		//  PRIVATE LISTENERS
		//
		//--------------------------------------------------------------------------
		
		private function onProjectPathChanged(event:Event):void
		{
			project.projectFolder = null;
			project.folderLocation = new FileLocation(newProjectPathSetting.stringValue);
			newProjectSourcePathSetting.project = project;
		}
		
		private function createClose(event:Event):void
		{
			var settings:SettingsView = event.target as SettingsView;
			
			settings.removeEventListener(SettingsView.EVENT_CLOSE, createClose);
			settings.removeEventListener(SettingsView.EVENT_SAVE, createSave);
			if (newProjectPathSetting) newProjectPathSetting.removeEventListener(PathSetting.PATH_SELECTED, onProjectPathChanged);
			
			delete templateLookup[settings.associatedData];
			
			GlobalEventDispatcher.getInstance().dispatchEvent(
				new CloseTabEvent(CloseTabEvent.EVENT_CLOSE_TAB, event.target as DisplayObject)
			);
		}
		
		private function createSave(event:Event):void
		{
			var view:SettingsView = event.target as SettingsView;
			var project:AS3ProjectVO = view.associatedData as AS3ProjectVO;
			var targetFolder:FileLocation = project.folderLocation;

			//save  project path in shared object
			cookie = SharedObject.getLocal("moonshine-ide-local");
			var tmpParent:FileLocation;
			if (_isProjectFromExistingSource)
			{
				var tmpIndex:int = model.recentSaveProjectPath.getItemIndex(project.folderLocation.fileBridge.nativePath);
				if (tmpIndex != -1) model.recentSaveProjectPath.removeItemAt(tmpIndex);
				tmpParent = project.folderLocation.fileBridge.parent;
			}
			else
			{
				tmpParent = project.folderLocation;
			}

			if (!model.recentSaveProjectPath.contains(tmpParent.fileBridge.nativePath))
			{
				model.recentSaveProjectPath.addItem(tmpParent.fileBridge.nativePath);
            }

			cookie.data["recentProjectPath"] = model.recentSaveProjectPath.source;
			cookie.flush();

            project = createFileSystemBeforeSave(project, view.exportProject);
			
			if (!_isProjectFromExistingSource) targetFolder = targetFolder.resolvePath(project.projectName);
			
			// Close settings view
			createClose(event);
			
			// Open main file for editing
			if (isAway3DProject)
			{
                project.folderLocation = targetFolder;
				GlobalEventDispatcher.getInstance().dispatchEvent(
					new ProjectEvent(ProjectEvent.ADD_PROJECT_AWAY3D, project)
				);
			}
			else
			{
				GlobalEventDispatcher.getInstance().dispatchEvent(
					new ProjectEvent(ProjectEvent.ADD_PROJECT, project)
				);
				
				GlobalEventDispatcher.getInstance().dispatchEvent( 
					new OpenFileEvent(OpenFileEvent.OPEN_FILE, project.targets[0])
				);
			}
		}
		
		private function createFileSystemBeforeSave(pvo:AS3ProjectVO, exportProject:AS3ProjectVO = null):AS3ProjectVO
		{
			// in case of create new project through Open Project option
			// we'll need to get the template project directory by it's name
			if (isOpenProjectCall && projectTemplateType)
			{
				for each (var i:TemplateVO in allProjectTemplates)
				{
					if (i.title == projectTemplateType)
					{
						setProjectType(i.title);

						var templateSettingsName:String = isVisualEditorProject && !exportProject ?
								"$Settings.veditorproj.template" :
								"$Settings.as3proj.template";

						var tmpLocation:FileLocation = pvo.folderLocation;
						var tmpName:String = pvo.projectName;
						var tmpExistingSource:Vector.<FileLocation> = pvo.projectWithExistingSourcePaths;
						var tmpIsExistingProjectSource:Boolean = pvo.isProjectFromExistingSource;
						templateLookup[pvo] = i.file;
						pvo = FlashDevelopImporter.parse(i.file.fileBridge.resolvePath(templateSettingsName));
						pvo.folderLocation = tmpLocation;
						pvo.projectName = tmpName;
						pvo.projectWithExistingSourcePaths = tmpExistingSource;
						pvo.isProjectFromExistingSource = tmpIsExistingProjectSource;
						break;
					}
				}
			}
			
			var templateDir:FileLocation = templateLookup[pvo];
			var projectName:String = pvo.projectName;
			var sourceFile:String = _isProjectFromExistingSource ? pvo.projectWithExistingSourcePaths[1].fileBridge.name.split(".")[0] : pvo.projectName;
			var sourceFileWithExtension:String = _isProjectFromExistingSource ? pvo.projectWithExistingSourcePaths[1].fileBridge.name : pvo.projectName + ((isActionScriptProject || isFeathersProject) ? ".as" : ".mxml");
			var sourcePath:String = _isProjectFromExistingSource ? pvo.folderLocation.fileBridge.getRelativePath(pvo.projectWithExistingSourcePaths[0]) : "src";
			var targetFolder:FileLocation = pvo.folderLocation;
			
			var movieVersion:String = "10.0";
			// lets load the target flash/air player version
			// since swf and air player both versioning same now,
			// we can load anyone's config file
			movieVersion = SDKUtils.getSdkSwfMajorVersion().toString()+".0";
			
			// Create project root directory
			if (!_isProjectFromExistingSource)
			{
				targetFolder = targetFolder.resolvePath(projectName);
				targetFolder.fileBridge.createDirectory();
			}
			
			// Time to do the templating thing!
			var th:TemplatingHelper = new TemplatingHelper();
			th.isProjectFromExistingSource = _isProjectFromExistingSource;
			th.templatingData["$ProjectName"] = projectName;
			
			var pattern:RegExp = new RegExp(/(_)/g);
			th.templatingData["$ProjectID"] = projectName.replace(pattern, "");
			th.templatingData["$SourcePath"] = sourcePath;
			th.templatingData["$SourceFile"] = sourcePath + File.separator + sourceFileWithExtension;
			th.templatingData["$SourceNameOnly"] = sourceFile;
			th.templatingData["$ProjectSWF"] = sourceFile +".swf";
			th.templatingData["$ProjectFile"] = sourceFileWithExtension;
			th.templatingData["$DesktopDescriptor"] = sourceFile;
			th.templatingData["$Settings"] = projectName;
			th.templatingData["$Certificate"] = projectName +"Certificate";
			th.templatingData["$Password"] = projectName +"Certificate";
			th.templatingData["$FlexHome"] = model.defaultSDK ? model.defaultSDK.fileBridge.nativePath : "";
			th.templatingData["$MovieVersion"] = movieVersion;
			if (_customFlexSDK)
			{
				th.templatingData["${flexlib}"] = _customFlexSDK;
            }
			else
			{
				th.templatingData["${flexlib}"] = (model.defaultSDK) ? model.defaultSDK.fileBridge.nativePath : "${SDK_PATH}";
            }

            if (exportProject)
            {
                exportProject.sourceFolder.fileBridge.copyTo(targetFolder.resolvePath("src"));
				th.isProjectFromExistingSource = true;
            }

            th.projectTemplate(templateDir, targetFolder);

			// we do not needs any further proceeding for non-flex projects, i.e away3d
			if (templateDir.fileBridge.name.indexOf("Away3D") != -1)
			{
				isAway3DProject = true;
				return pvo;
            }

			// If this an ActionScript Project then we need to copy selective file/folders for web or desktop
			var descriptorFileLocation:FileLocation;
			var isAIR:Boolean = templateDir.resolvePath("build_air").fileBridge.exists;
			if (isActionScriptProject || isAIR || isMobileProject)
			{
				if (activeType == ProjectType.AS3PROJ_AS_AIR)
				{
					// build folder modification
					th.projectTemplate(templateDir.resolvePath("build_air"), targetFolder.resolvePath("build"));
					descriptorFileLocation = targetFolder.resolvePath("build/"+ sourceFile +"-app.xml");
					try
					{
						descriptorFileLocation.fileBridge.moveTo(targetFolder.resolvePath(sourcePath + File.separator + sourceFile +"-app.xml"), true);
					}
					catch(e:Error)
					{
						descriptorFileLocation.fileBridge.moveToAsync(targetFolder.resolvePath(sourcePath + File.separator + sourceFile +"-app.xml"), true);
					}
				}
				else
				{
					th.projectTemplate(templateDir.resolvePath("build_web"), targetFolder.resolvePath("build"));
					th.projectTemplate(templateDir.resolvePath("bin-debug_web"), targetFolder.resolvePath("bin-debug"));
					th.projectTemplate(templateDir.resolvePath("html-template_web"), targetFolder.resolvePath("html-template"));
				}
				
				// we also needs to delete unnecessary folders
				var folderToDelete1:FileLocation = targetFolder.resolvePath("build_air");
				var folderToDelete2:FileLocation = targetFolder.resolvePath("build_web");
				var folderToDelete3:FileLocation = targetFolder.resolvePath("bin-debug_web");
				var folderToDelete4:FileLocation = targetFolder.resolvePath("html-template_web");
				try
				{
					folderToDelete1.fileBridge.deleteDirectory(true);
					if (isActionScriptProject)
					{
						folderToDelete2.fileBridge.deleteDirectory(true);
						folderToDelete3.fileBridge.deleteDirectory(true);
						folderToDelete4.fileBridge.deleteDirectory(true);
					}
				}
				catch (e:Error)
				{
					folderToDelete1.fileBridge.deleteDirectoryAsync(true);
					if (isActionScriptProject)
					{
						folderToDelete2.fileBridge.deleteDirectoryAsync(true);
						folderToDelete3.fileBridge.deleteDirectoryAsync(true);
						folderToDelete4.fileBridge.deleteDirectoryAsync(true);
					}
				}
			}
			
			// creating certificate conditional checks
			if (!descriptorFileLocation || !descriptorFileLocation.fileBridge.exists)
			{
				descriptorFileLocation = targetFolder.resolvePath("application.xml");
				if (!descriptorFileLocation.fileBridge.exists)
				{
					descriptorFileLocation = targetFolder.resolvePath(sourcePath + File.separator + sourceFile +"-app.xml");
				}
			}
			
			if (descriptorFileLocation.fileBridge.exists)
			{
				// lets update $SWFVersion with SWF version now
				var stringOutput:String = descriptorFileLocation.fileBridge.read() as String;
				var firstNamespaceQuote:int = stringOutput.indexOf('"', stringOutput.indexOf("<application xmlns=")) + 1;
				var lastNamespaceQuote:int = stringOutput.indexOf('"', firstNamespaceQuote);
				var currentAIRNamespaceVersion:String = stringOutput.substring(firstNamespaceQuote, lastNamespaceQuote);
				
				stringOutput = stringOutput.replace(currentAIRNamespaceVersion, "http://ns.adobe.com/air/application/"+ movieVersion);
				descriptorFileLocation.fileBridge.save(stringOutput);
			}

			var projectSettingsFile:String = isVisualEditorProject && !exportProject ?
                    projectName+".veditorproj" :
                    projectName+".as3proj";

			// Figure out which one is the settings file
			var settingsFile:FileLocation = targetFolder.resolvePath(projectSettingsFile);
            var descriptorFile:File = (isMobileProject || (isActionScriptProject && activeType == ProjectType.AS3PROJ_AS_AIR)) ?
                    new File(project.folderLocation.fileBridge.nativePath + File.separator + sourcePath + File.separator + sourceFile +"-app.xml") :
                    null;
			
			// Set some stuff to get the paths right
			pvo = FlashDevelopImporter.parse(settingsFile, projectName, descriptorFile);
			pvo.projectName = projectName;
			pvo.buildOptions.customSDKPath = _customFlexSDK;
			_customFlexSDK = null;
			
			// Write settings
			FlashDevelopExporter.export(pvo, settingsFile);

			return pvo;
		}

        private function setProjectType(templateName:String):void
        {
			if (templateName.indexOf(ProjectTemplateType.VISUAL_EDITOR) != -1)
			{
				isVisualEditorProject = true;
			}

            if (templateName.indexOf(ProjectTemplateType.FEATHERS) != -1)
            {
                isFeathersProject = true;
            }

            if (templateName.indexOf(ProjectTemplateType.ACTIONSCRIPT) != -1)
            {
                isActionScriptProject = true;
            }
            else if (templateName.indexOf(ProjectTemplateType.MOBILE) != -1)
            {
                isMobileProject = true;
            }
            else
            {
                isActionScriptProject = false;
            }
        }
    }
}
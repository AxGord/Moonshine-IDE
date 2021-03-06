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
package actionScripts.plugin.recentlyOpened
{
    import flash.events.Event;
    import flash.net.SharedObject;
    import flash.utils.clearTimeout;
    import flash.utils.setTimeout;
    
    import mx.collections.ArrayCollection;
    
    import actionScripts.events.FilePluginEvent;
    import actionScripts.events.GeneralEvent;
    import actionScripts.events.ProjectEvent;
    import actionScripts.events.StartupHelperEvent;
    import actionScripts.factory.FileLocation;
    import actionScripts.plugin.IMenuPlugin;
    import actionScripts.plugin.PluginBase;
    import actionScripts.plugin.actionscript.as3project.vo.AS3ProjectVO;
    import actionScripts.ui.LayoutModifier;
    import actionScripts.ui.menu.vo.MenuItem;
    import actionScripts.utils.OSXBookmarkerNotifiers;
    import actionScripts.utils.ObjectTranslator;
    import actionScripts.utils.SDKUtils;
    import actionScripts.utils.SharedObjectConst;
    import actionScripts.utils.UtilsCore;
    import actionScripts.valueObjects.ConstantsCoreVO;
    import actionScripts.valueObjects.MobileDeviceVO;
    import actionScripts.valueObjects.ProjectReferenceVO;
    import actionScripts.valueObjects.SDKReferenceVO;
    
    import components.views.project.TreeView;

	public class RecentlyOpenedPlugin extends PluginBase implements IMenuPlugin
	{
		public static const RECENT_PROJECT_LIST_UPDATED:String = "RECENT_PROJECT_LIST_UPDATED";
		public static const RECENT_FILES_LIST_UPDATED:String = "RECENT_FILES_LIST_UPDATED";
		
		override public function get name():String			{ return "Recently Opened Plugin"; }
		override public function get author():String		{ return ConstantsCoreVO.MOONSHINE_IDE_LABEL +" Project Team"; }
		override public function get description():String	{ return "Stores the last opened file paths."; }
		
		private var cookie:SharedObject;
		
		override public function activate():void
		{
			super.activate();
			
			cookie = SharedObject.getLocal(SharedObjectConst.MOONSHINE_IDE_LOCAL);

			if (model.recentlyOpenedFiles.length == 0)
			{
				restoreFromCookie();
			}
			
			dispatcher.addEventListener(ProjectEvent.ADD_PROJECT, handleAddProject);
			//dispatcher.addEventListener(ProjectEvent.ADD_PROJECT_AWAY3D, handleAddProject, false, 0, true);
			dispatcher.addEventListener(ProjectEvent.FLEX_SDK_UDPATED, onFlexSDKUpdated);
			dispatcher.addEventListener(ProjectEvent.WORKSPACE_UPDATED, onWorkspaceUpdated);
			dispatcher.addEventListener(SDKUtils.EVENT_SDK_PROMPT_DNS, onSDKExtractDNSUpdated);
			dispatcher.addEventListener(StartupHelperEvent.EVENT_DNS_GETTING_STARTED, onGettingStartedDNSUpdated);
			dispatcher.addEventListener(FilePluginEvent.EVENT_JAVA_TYPEAHEAD_PATH_SAVE, onJavaPathForTypeaheadSave);
			dispatcher.addEventListener(LayoutModifier.SAVE_LAYOUT_CHANGE_EVENT, onSaveLayoutChangeEvent);
			dispatcher.addEventListener(GeneralEvent.DEVICE_UPDATED, onDeviceListUpdated, false, 0, true);
			dispatcher.addEventListener(RecentlyOpenedPlugin.RECENT_PROJECT_LIST_UPDATED, updateRecetProjectList);
			dispatcher.addEventListener(RecentlyOpenedPlugin.RECENT_FILES_LIST_UPDATED, updateRecetFileList);
			// Give other plugins a chance to cancel the event
			dispatcher.addEventListener(FilePluginEvent.EVENT_FILE_OPEN, handleOpenFile, false, -100);
		}
		
		public function getMenu():MenuItem
		{
			return UtilsCore.getRecentFilesMenu();
		}
		
		private function restoreFromCookie():void
		{
			// Uncomment & run to delete cookie
			//delete cookie.data.recentFiles;
			//delete cookie.data.recentProjects;
			
			// Load & unserialize recent items
			var recentFiles:Array = cookie.data.recentFiles;
			var recent:Array = [];
			var f:FileLocation;
			var file:Object;
			var object:Object;
			var projectReferenceVO:ProjectReferenceVO;
			if (cookie.data.hasOwnProperty('recentFiles'))
			{
				if (!ConstantsCoreVO.IS_AIR)
				{
					model.recentlyOpenedProjectOpenedOption.source = cookie.data.recentProjectsOpenedOption;
				}
				else
				{
					recentFiles = cookie.data.recentFiles;
                    for (var i:int = 0; i < recentFiles.length; i++)
					{
						file = recentFiles[i];
						projectReferenceVO = ProjectReferenceVO.getNewRemoteProjectReferenceVO(file);
						if (projectReferenceVO.path && projectReferenceVO.path != "")
						{
							f = new FileLocation(projectReferenceVO.path);
							if (f.fileBridge.exists)
							{
								recent.push(projectReferenceVO);
                            }
							else
							{
								cookie.data.recentFiles.splice(i, 1);
							}
						}
					}

                    cookie.flush();
					model.recentlyOpenedFiles.source = recent;
				}
			}
			
			if (cookie.data.hasOwnProperty('recentProjects'))
			{
				recentFiles = cookie.data.recentProjects;
				recent = [];

				for (var j:int = 0; j < recentFiles.length; j++)
				{
					file = recentFiles[j];
					projectReferenceVO = ProjectReferenceVO.getNewRemoteProjectReferenceVO(file);
					if (projectReferenceVO.path && projectReferenceVO.path != "")
					{
						f = new FileLocation(projectReferenceVO.path);
						if (ConstantsCoreVO.IS_AIR && f.fileBridge.exists)
						{
							recent.push(projectReferenceVO);
						}
						else if (!ConstantsCoreVO.IS_AIR)
						{
							recent.push(projectReferenceVO);
						}
						else
						{
							cookie.data.recentProjects.splice(j, 1);
						}
					}
				}
				cookie.flush();
				model.recentlyOpenedProjects.source = recent;
			}
			
			if (cookie.data.hasOwnProperty('recentProjectsOpenedOption'))
			{
				if (!ConstantsCoreVO.IS_AIR)
				{
					model.recentlyOpenedProjectOpenedOption.source = cookie.data.recentProjectsOpenedOption;
				}
				else
				{
					var recentProjectsOpenedOptions:Array = cookie.data.recentProjectsOpenedOption;
					recent = [];
					for each (object in recentProjectsOpenedOptions)
					{
						f = new FileLocation(object.path);
						if (f.fileBridge.exists) recent.push(object);
					}
					model.recentlyOpenedProjectOpenedOption.source = recent;
				}
			}
			
			if (cookie.data.hasOwnProperty('userSDKs'))
			{
				for each (object in cookie.data.userSDKs)
				{
					var tmpSDK:SDKReferenceVO = SDKReferenceVO.getNewReference(object);
					if (new FileLocation(tmpSDK.path).fileBridge.exists) model.userSavedSDKs.addItem(tmpSDK);
				}
			}
			
			if (cookie.data.hasOwnProperty('moonshineWorkspace')) OSXBookmarkerNotifiers.workspaceLocation = new FileLocation(cookie.data.moonshineWorkspace);
			if (cookie.data.hasOwnProperty('isWorkspaceAcknowledged')) OSXBookmarkerNotifiers.isWorkspaceAcknowledged = (cookie.data["isWorkspaceAcknowledged"] == "true") ? true : false;
			if (cookie.data.hasOwnProperty('isBundledSDKpromptDNS')) ConstantsCoreVO.IS_BUNDLED_SDK_PROMPT_DNS = (cookie.data["isBundledSDKpromptDNS"] == "true") ? true : false;
			if (cookie.data.hasOwnProperty('isSDKhelperPromptDNS')) ConstantsCoreVO.IS_SDK_HELPER_PROMPT_DNS = (cookie.data["isSDKhelperPromptDNS"] == "true") ? true : false;
			if (cookie.data.hasOwnProperty('isGettingStartedDNS')) ConstantsCoreVO.IS_GETTING_STARTED_DNS = (cookie.data["isGettingStartedDNS"] == "true") ? true : false;
			if (cookie.data.hasOwnProperty('javaPathForTypeahead')) model.javaPathForTypeAhead = new FileLocation(cookie.data["javaPathForTypeahead"]);
			if (cookie.data.hasOwnProperty('devicesAndroid'))
			{
				ConstantsCoreVO.TEMPLATES_ANDROID_DEVICES = new ArrayCollection();
				ConstantsCoreVO.TEMPLATES_IOS_DEVICES = new ArrayCollection();
				
				for each (object in cookie.data.devicesAndroid)
				{
					ConstantsCoreVO.TEMPLATES_ANDROID_DEVICES.addItem(ObjectTranslator.objectToInstance(object, MobileDeviceVO));
				}
				for each (object in cookie.data.devicesIOS)
				{
					ConstantsCoreVO.TEMPLATES_IOS_DEVICES.addItem(ObjectTranslator.objectToInstance(object, MobileDeviceVO));
				}
			}
			else
			{
				ConstantsCoreVO.generateDevices();
			}
			
			LayoutModifier.parseCookie(cookie);
		}

		private function handleAddProject(event:ProjectEvent):void
		{
			// Find & remove project if already present
			//var f:File = (event.project.projectFile) ? event.project.projectFile : event.project.folder;
			var f:FileLocation = event.project.folderLocation;
			var toRemove:int = -1;
			for each (var file:Object in model.recentlyOpenedProjects)
			{
				if (file.path == f.fileBridge.nativePath)
				{
					toRemove = model.recentlyOpenedProjects.getItemIndex(file);
					break;
				}
			}
			if (toRemove != -1) 
			{
				model.recentlyOpenedProjects.removeItemAt(toRemove);
				model.recentlyOpenedProjectOpenedOption.removeItemAt(toRemove);
			}
			
			var customSDKPath:String = null;
			if(event.project is AS3ProjectVO)
			{
				customSDKPath = (event.project as AS3ProjectVO).buildOptions.customSDKPath;
			}
			var tmpSOReference: ProjectReferenceVO = new ProjectReferenceVO();
			tmpSOReference.name = event.project.name;
			tmpSOReference.sdk = customSDKPath ? customSDKPath : (model.defaultSDK ? model.defaultSDK.fileBridge.nativePath : null);
			tmpSOReference.path = event.project.folderLocation.fileBridge.nativePath;
			//tmpSOReference.isAway3D = (event.type == ProjectEvent.ADD_PROJECT_AWAY3D);
			
			model.recentlyOpenedProjects.addItemAt(tmpSOReference, 0);
			model.recentlyOpenedProjectOpenedOption.addItemAt({path:f.fileBridge.nativePath, option:(event.extras ? event.extras[0] : "")}, 0);
			
			//Moon-166 fix: This will set selected project in the tree view
			/*var tmpTreeView:TreeView = model.mainView.getTreeViewPanel();
			tmpTreeView.tree.selectedItem = model.activeProject.projectFolder;*/
			
			var timeoutValue:uint = setTimeout(function():void{
				var tmpTreeView:TreeView = model.mainView.getTreeViewPanel();
				if (model.activeProject)
				{
					tmpTreeView.tree.selectedItem = model.activeProject.projectFolder;
                }
				clearTimeout(timeoutValue);
			}, 200);
			
            var timeoutRecentProjectListValue:uint = setTimeout(function():void
			{
				dispatcher.dispatchEvent(new Event(RECENT_PROJECT_LIST_UPDATED));
				clearTimeout(timeoutRecentProjectListValue);
			}, 300);
		}
		
		private function handleOpenFile(event:FilePluginEvent):void
		{
			if (event.isDefaultPrevented()) return;

			// File might have been removed
			var f:FileLocation = event.file;
			if (!f || !f.fileBridge.exists) return;			
			
			// Find item & remove it if already present (path-based, since it's two different File objects)
			var toRemove:int = -1;
			for each (var file:Object in model.recentlyOpenedFiles)
			{
				if (file.path == f.fileBridge.nativePath)
				{
					toRemove = model.recentlyOpenedFiles.getItemIndex(file);
					break;
				}
			}
			if (toRemove != -1) model.recentlyOpenedFiles.removeItemAt(toRemove);
			
			var tmpSOReference: ProjectReferenceVO = new ProjectReferenceVO();
			tmpSOReference.name = (f.fileBridge.name.indexOf(".") == -1) ? f.fileBridge.name +"."+ f.fileBridge.extension : f.fileBridge.name;
			tmpSOReference.path = f.fileBridge.nativePath;
			model.recentlyOpenedFiles.addItemAt(tmpSOReference, 0);
			//model.selectedprojectFolders
			
			setTimeout(function():void
			{
				dispatcher.dispatchEvent(new Event(RECENT_FILES_LIST_UPDATED));
			}, 300);
		}
		
		private function updateRecetProjectList(event:Event):void
		{
			save(model.recentlyOpenedProjects.source, 'recentProjects');
			save(model.recentlyOpenedProjectOpenedOption.source, 'recentProjectsOpenedOption');
		}
		
		private function updateRecetFileList(event:Event):void
		{
			save(model.recentlyOpenedFiles.source, 'recentFiles');
		}
		
		private function onFlexSDKUpdated(event:ProjectEvent):void
		{
			// we need some works here, we don't 
			// wants any bundled SDKs to be saved in 
			// the saved list
			var tmpArr:Array = [];
			for each (var i:SDKReferenceVO in model.userSavedSDKs)
			{
				if (i.status != SDKUtils.BUNDLED) tmpArr.push(i);
			}
			
			// and then save
			save(tmpArr, 'userSDKs');
		}
		
		private function onWorkspaceUpdated(event:ProjectEvent):void
		{
			if ((OSXBookmarkerNotifiers.workspaceLocation != null) && OSXBookmarkerNotifiers.workspaceLocation.fileBridge.exists) cookie.data["moonshineWorkspace"] = OSXBookmarkerNotifiers.workspaceLocation.fileBridge.nativePath;
			cookie.data["isWorkspaceAcknowledged"] = OSXBookmarkerNotifiers.isWorkspaceAcknowledged.toString();
			cookie.flush();
		}
		
		private function onSDKExtractDNSUpdated(event:Event):void
		{
			cookie.data["isBundledSDKpromptDNS"] = ConstantsCoreVO.IS_BUNDLED_SDK_PROMPT_DNS.toString();
			cookie.data["isSDKhelperPromptDNS"] = ConstantsCoreVO.IS_SDK_HELPER_PROMPT_DNS.toString();
			cookie.flush();
		}
		
		private function onGettingStartedDNSUpdated(event:Event):void
		{
			cookie.data["isGettingStartedDNS"] = ConstantsCoreVO.IS_GETTING_STARTED_DNS.toString();
			cookie.flush();
		}
		
		private function onJavaPathForTypeaheadSave(event:FilePluginEvent):void
		{
			if(event.file)
			{
				cookie.data["javaPathForTypeahead"] = event.file.fileBridge.nativePath;
				cookie.flush();
			}
		}
		
		private function onSaveLayoutChangeEvent(event:GeneralEvent):void
		{
			cookie.data[event.value.label] = event.value.value;
			cookie.flush();
		}
		
		private function onDeviceListUpdated(event:GeneralEvent):void
		{
			cookie.data["devicesAndroid"] = ConstantsCoreVO.TEMPLATES_ANDROID_DEVICES.source;
			cookie.data["devicesIOS"] = ConstantsCoreVO.TEMPLATES_IOS_DEVICES.source;
			cookie.flush();
		}
		
		private function save(recent:Array, key:String):void
		{
			// Only save the ten latest files
			/*if (recent.length > 10)
			{
				recent = recent.slice(0, 10);
			}*/
			// Serialize down to paths
			var toSave:Array = [];
			for each (var f:Object in recent)
			{
				if (f is FileLocation) toSave.push(f.fileBridge.nativePath);
				else toSave.push(f);
			}
			
			// Add to LocalObject
			cookie.data[key] = toSave;
			cookie.flush();
		}
	}
}
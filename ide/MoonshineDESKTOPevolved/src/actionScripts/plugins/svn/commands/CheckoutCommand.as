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
package actionScripts.plugins.svn.commands
{
	import flash.desktop.NativeApplication;
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.utils.IDataInput;
	
	import actionScripts.events.ProjectEvent;
	import actionScripts.events.StatusBarEvent;
	import actionScripts.plugins.git.model.MethodDescriptor;
	import actionScripts.plugins.svn.event.SVNEvent;
	
	public class CheckoutCommand extends SVNCommandBase
	{
		private var cmdFile:File;
		private var isEventReported:Boolean;
		private var targetFolder:String;
		private var lastEventServerCertificateState:Boolean;
		
		public function CheckoutCommand(executable:File, root:File)
		{
			super(executable, root);
			//cmdFile = new File("c:\\Windows\\System32\\cmd.exe");
		}
		
		public function checkout(event:SVNEvent, folder:String, isTrustServerCertificateSVN:Boolean):void
		{
			if (runningForFile)
			{
				error("Currently running, try again later.");
				return;
			}
			
			lastKnownMethod = null;
			lastEvent = event;
			targetFolder = folder;
			lastEventServerCertificateState = isTrustServerCertificateSVN;
			notice("Trying to check out %s. May take a while.", event.url);
			
			isEventReported = false;
			customInfo = new NativeProcessStartupInfo();
			customInfo.executable = executable;
			//customInfo.executable = cmdFile; 
			
			// http://stackoverflow.com/questions/1625406/using-tortoisesvn-via-the-command-line
			var args:Vector.<String> = new Vector.<String>();
			var username:String;
			var password:String;
			args.push("checkout");
			if (event.repository && event.repository.userName && event.repository.userPassword)
			{
				username = event.repository.userName;
				password = event.repository.userPassword;
			}
			else if (event.authObject != null)
			{
				username = event.authObject.username;
				password = event.authObject.password;
			}
			if (username != null && password != null)
			{
				args.push("--username");
				args.push(username);
				args.push("--password");
				args.push(password);
			}
			args.push(event.url);
			args.push(targetFolder);
			args.push("--non-interactive");
			if (isTrustServerCertificateSVN) args.push("--trust-server-cert");
			
			customInfo.arguments = args;
			customInfo.workingDirectory = event.file;
			
			dispatcher.dispatchEvent(new StatusBarEvent(StatusBarEvent.PROJECT_BUILD_STARTED, "Requested", "SVN Process ", false));
			
			startShell(true);
			customProcess.start(customInfo);
			runningForFile = event.file;
		}
		
		private function startShell(start:Boolean):void
		{
			if (start)
			{
				customProcess = new NativeProcess();
				customProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, svnError);
				customProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, svnOutput);
				customProcess.addEventListener(NativeProcessExitEvent.EXIT, svnExit);
			}
			else
			{
				if (!customProcess) return;
				if (customProcess.running) customProcess.exit();
				customProcess.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, svnError);
				customProcess.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, svnOutput);
				customProcess.removeEventListener(NativeProcessExitEvent.EXIT, svnExit);
				customProcess = null;
				customInfo = null;
				runningForFile = null;
			}
		}
		
		protected function svnError(event:ProgressEvent):void
		{
			var output:IDataInput = customProcess.standardError;
			var data:String = output.readUTFBytes(output.bytesAvailable);
			
			var match:Array = data.toLowerCase().match(/Error validating server certificate for/);
			if (match) 
			{
				//serverCertificatePrompt(data);
				//return;
			}
			
			match = data.toLowerCase().match(/authentication failed/);
			if (match)
			{
				lastKnownMethod = new MethodDescriptor(this, "checkout", lastEvent, targetFolder, lastEventServerCertificateState);
				openAuthentication();
			}
	
			error("%s", data);
			dispatcher.dispatchEvent(new StatusBarEvent(StatusBarEvent.PROJECT_BUILD_ENDED));
			dispatcher.dispatchEvent(new SVNEvent(SVNEvent.SVN_ERROR, null));
			startShell(false);
		}
		
		protected function svnOutput(event:ProgressEvent):void
		{
			if (!isEventReported)
			{
				dispatcher.dispatchEvent(new SVNEvent(SVNEvent.SVN_RESULT, null));
				isEventReported = true;
			}
			
			var output:IDataInput = customProcess.standardOutput;
			var data:String = output.readUTFBytes(output.bytesAvailable);
			
			notice("%s", data);
		}
		
		protected function svnExit(event:NativeProcessExitEvent):void
		{
			if (event.exitCode == 0)
			{
				dispatcher.dispatchEvent(new ProjectEvent(ProjectEvent.EVENT_IMPORT_PROJECT_NO_BROWSE_DIALOG, new File(runningForFile.nativePath + File.separator + targetFolder)));
				/*var p:ProjectVO = new ProjectVO(new FileLocation(runningForFile.nativePath));
				dispatcher.dispatchEvent(
					new ProjectEvent(ProjectEvent.ADD_PROJECT, p)
				);*/
			}
			else
			{
				// Checkout failed
			}
			
			/*runningForFile = null;
			customProcess = null;*/
			dispatcher.dispatchEvent(new StatusBarEvent(StatusBarEvent.PROJECT_BUILD_ENDED));
			startShell(false);
		}
	}
}
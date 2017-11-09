////////////////////////////////////////////////////////////////////////////////
//
//  Licensed to the Apache Software Foundation (ASF) under one or more
//  contributor license agreements.  See the NOTICE file distributed with
//  this work for additional information regarding copyright ownership.
//  The ASF licenses this file to You under the Apache License, Version 2.0
//  (the "License"); you may not use this file except in compliance with
//  the License.  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
////////////////////////////////////////////////////////////////////////////////
package actionScripts.plugins.ui.editor
{
    import actionScripts.events.AddTabEvent;
    import actionScripts.events.ChangeEvent;
    import actionScripts.interfaces.IVisualEditorViewer;
    import actionScripts.plugin.actionscript.as3project.vo.AS3ProjectVO;
    import actionScripts.plugins.help.view.VisualEditorView;
    import actionScripts.plugins.help.view.events.VisualEditorViewChangeEvent;
    import actionScripts.ui.editor.*;
    import actionScripts.ui.editor.text.TextEditor;
    import actionScripts.ui.tabview.CloseTabEvent;

    import flash.events.Event;

    import flash.filesystem.File;

    public class VisualEditorViewer extends BasicTextEditor implements IVisualEditorViewer
    {
        private var visualEditorView:VisualEditorView;
        
        public function VisualEditorViewer()
        {
            super();
        }

        override protected function initializeChildrens():void
        {
            isVisualEditor = true;
            
            visualEditorView = new VisualEditorView();
            visualEditorView.percentWidth = 100;
            visualEditorView.percentHeight = 100;
            visualEditorView.addEventListener(VisualEditorViewChangeEvent.CODE_CHANGE, onVisualEditorViewCodeChange);

            editor = new TextEditor(true);
            editor.percentHeight = 100;
            editor.percentWidth = 100;
            editor.addEventListener(ChangeEvent.TEXT_CHANGE, handleTextChange);
            editor.dataProvider = "";

            visualEditorView.codeEditor = editor;
            
            dispatcher.addEventListener(AddTabEvent.EVENT_ADD_TAB, onTabOpenClose);
            dispatcher.addEventListener(CloseTabEvent.EVENT_CLOSE_TAB, onTabOpenClose);
        }

        private function onVisualEditorViewCodeChange(event:VisualEditorViewChangeEvent):void
        {
            var mxmlCode:XML = visualEditorView.visualEditor.editingSurface.toMXML();
            var mxmlCodeList:XMLList = mxmlCode.children();

            var mxmlEditor:XML = new XML(editor.dataProvider);
            mxmlEditor.setChildren("");

            for each (var child:XML in mxmlCodeList)
            {
                mxmlEditor.appendChild(child);
            }

            var markAsXml:String = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
            var xmlString:String = markAsXml + mxmlEditor.toXMLString();

            editor.dataProvider = xmlString;

            _isChanged = visualEditorView.visualEditor.editingSurface.hasChanged;
        }

        override protected function createChildren():void
        {
            addElement(visualEditorView);
            
            super.createChildren();
        }

        override public function save():void
        {
            visualEditorView.visualEditor.saveEditedFile();
            super.save();
        }

        override protected function openHandler(event:Event):void
        {
            super.openHandler(event);

            createVisualEditorFile();
        }

        private function onTabOpenClose(event:Event):void
        {
            if (!visualEditorView.visualEditor) return;
            
            visualEditorView.visualEditor.editingSurface.selectedItem = null;
        }

        private function createVisualEditorFile():void
        {
            var veFilePath:String = getVisualEditorFilePath();
            if (veFilePath)
            {
                visualEditorView.visualEditor.loadFile(veFilePath);
            }
        }

        private function getVisualEditorFilePath():String
        {
            var splittedFileName:Array = file.fileBridge.name.split(".");

            if (splittedFileName.length == 2)
            {
                var cleanFileName:String = splittedFileName[0];
                var as3Project:AS3ProjectVO = model.activeProject as AS3ProjectVO;
                return as3Project.visualEditorSourceFolder
                        .fileBridge.nativePath
                        .concat(File.separator, cleanFileName, ".xml");
            }

            return null;
        }
    }
}

/*
Copyright 2016-2018 Bowler Hat LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
package com.nextgenactionscript.vscode.utils;

import org.apache.royale.compiler.problems.FontEmbeddingNotSupported;
import org.apache.royale.compiler.problems.ICompilerProblem;
import org.eclipse.lsp4j.DiagnosticSeverity;

public class CompilerProblemFilter
{
	public CompilerProblemFilter()
	{
	}

	public boolean warnings = true;
	public boolean royaleProblems = true;

	public boolean isAllowed(ICompilerProblem problem)
	{
		if (!warnings)
		{
			DiagnosticSeverity severity = LanguageServerCompilerUtils.getDiagnosticSeverityFromCompilerProblem(problem);
			if (severity.equals(DiagnosticSeverity.Warning))
			{
				return false;
			}
		}
        if (!royaleProblems)
        {
            //the following errors get special treatment if the framework SDK's
            //compiler isn't Falcon

            if (problem.getClass().equals(FontEmbeddingNotSupported.class))
            {
                //ignore this error because the framework SDK can embed fonts
                return false;
            }
		}
		return true;
	}
}
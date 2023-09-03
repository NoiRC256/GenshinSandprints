//  Copyright (c) 2017 - present amlovey
//  
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;
using UnityEditor.Callbacks;
using System.Linq;
using UnityEditorInternal;
using System;
using System.Text.RegularExpressions;
using System.Net;
using System.Text;

#if UNITY_EDITOR_WIN
using System.Diagnostics;
#endif

namespace ShaderlabVSCode
{
    public class DataPair
    {
        public string Uri1;
        public string Uri2;
    }

    public class ShaderlabVSCodeEditor
    {
        [MenuItem("Tools/ShaderlabVSCode/Download Visual Studio Code", false, 11)]
        public static void DownloadVSCode()
        {
            Application.OpenURL("https://code.visualstudio.com/Download");
        }

        [MenuItem("Tools/ShaderlabVSCode/Online Documentation", false, 33)]
        public static void OpenOnlineDocumentation()
        {
            Application.OpenURL("http://www.amlovey.com/shaderlabvscode/index/");
        }

        [MenuItem("Tools/ShaderlabVSCode/Open An Issue", false, 33)]
        public static void OpenIssue()
        {
            Application.OpenURL("https://github.com/amloveyweb/shaderlabvscode/issues");
        }

        [MenuItem("Tools/ShaderlabVSCode/Rate And Review", false, 33)]
        public static void StarAndReview()
        {
            Application.OpenURL("https://assetstore.unity.com/packages/slug/94653?aid=1011lGoJ");
        }

        #region Use VSCode to open files

        static string[] SHADER_FILE_EXTENSIONS = new string[] {
            ".shader",
            ".compute",
            ".cginc",
            ".glslinc",
            ".hlsl",
            ".cg"
        };

        [OnOpenAssetAttribute(0)]
        public static bool OpenInVSCode(int instanceID, int line)
        {
            string path = AssetDatabase.GetAssetPath(EditorUtility.InstanceIDToObject(instanceID));
            path = Path.Combine(Path.Combine(Application.dataPath, ".."), path);
            path = Path.GetFullPath(path);
            
            if (SHADER_FILE_EXTENSIONS.Any(extension => path.Trim().ToLower().EndsWith(extension)))
            {
                if (VSCodeBridge.IsVSCodeExists())
                {
                    VSCodeBridge.CallVSCodeWithArgs(string.Format("\"{0}\"", path));
                }
                else
                {
                    InternalEditorUtility.OpenFileAtLineExternal(path, 0);
                }
                return true;
            }

            return false;
        }

        [MenuItem("Tools/ShaderlabVSCode/Update Data of VSCode Extension", false, 22)]
        public static void UpdateData()
        {
            bool updated = false;

            try
            {
                var extensionsFolder = GetExtensionPath();
                if (string.IsNullOrEmpty(extensionsFolder))
                {
                    EditorUtility.DisplayDialog("Not Found", "Seems like there are no ShaderlabVSCode extension installed.", "OK");
                    return;
                }

                string title = "Updating Data of ShaderlabVSCode Extension";
                EditorUtility.DisplayProgressBar(title, title, 0);
                int count = 0;

                foreach (var pair in DATA_PAIRS)
                {
                    EditorUtility.DisplayProgressBar(title, title, (count + 1) * 1.0f / DATA_PAIRS.Count);
                    var webContent = GetContentFromWeb(pair.Uri1);
                    var localPath = Path.Combine(extensionsFolder, pair.Uri2);
                    var localContent = File.ReadAllText(localPath);

                    int v1 = GetVersionId(webContent);
                    int v2 = GetVersionId(localContent);

                    if (v1 > v2)
                    {
                        File.WriteAllText(localPath, webContent);
                        updated = true;
                    }
                    count++;
                }
            }
            catch (System.Exception)
            {

            }

            EditorUtility.ClearProgressBar();

            if (updated)
            {
                EditorUtility.DisplayDialog("Done", "Completed! The new data will take effect after reload VSCode window.", "OK");
            }
            else
            {
                EditorUtility.DisplayDialog("Done", "Data is already up to date!", "OK");
            }
        }

        private static string GetContentFromWeb(string url)
        {
            WebClient client = new WebClient();
            var bytes = client.DownloadData(url);
            return Encoding.UTF8.GetString(bytes);
        }

        private static int GetVersionId(string code)
        {
            string pattern = "\"[Vv]ersion\"\\s*?:\\s*?(?<VER>\\d+?)\\s*?,";
            var match = Regex.Match(code, pattern);
            if (match != null)
            {
                var version = match.Groups["VER"].Value;
                if (!string.IsNullOrEmpty(version))
                {
                    return int.Parse(version);
                }
            }

            return -1;
        }

        private static List<DataPair> DATA_PAIRS = new List<DataPair>()
        {
            new DataPair(){ Uri1 = "http://www.amlovey.com/shaderlab/functions.json", Uri2 = "out/src/data/functions.json" },
            new DataPair(){ Uri1 = "http://www.amlovey.com/shaderlab/intellisense.json", Uri2 = "out/src/data/intellisense.json" },
            new DataPair(){ Uri1 = "http://www.amlovey.com/shaderlab/keywords.json", Uri2 = "out/src/data/keywords.json" },
            new DataPair(){ Uri1 = "http://www.amlovey.com/shaderlab/values.json", Uri2 = "out/src/data/values.json" },
            new DataPair(){ Uri1 = "http://www.amlovey.com/shaderlab/shaderlab.json", Uri2 = "snippets/shaderlab.json" },
        };

        private static string GetExtensionPath()
        {
            string path;
#if UNITY_EDITOR_WIN
            path = Environment.ExpandEnvironmentVariables(@"%USERPROFILE%\.vscode\extensions");
#else
            path = Environment.GetFolderPath(Environment.SpecialFolder.Personal) + "/.vscode/extensions";
#endif

            if (Directory.Exists(path))
            {
                var subDirs = Directory.GetDirectories(path);
                foreach (var item in subDirs)
                {
                    if (item.ToLower().Contains("amlovey.shaderlabvscode")
                        && !item.ToLower().Contains("shaderlabvscodefree"))
                    {
                        return item;
                    }
                }
            }

            return null;
        }

        #endregion

        #region Script Templates

        [MenuItem("Tools/ShaderlabVSCode/Install Script Templates", false, 44)]
        public static void InstallScriptTemplatesMenu()
        {
            InstallScriptTemplates();
            EditorUtility.DisplayDialog("Success", "Script templates will available after Unity Editor restared", "Ok");
        }

        private static void InstallScriptTemplates()
        {
            int order = 90;
            string category = "Shader";
            string srcFolderInProject = GetScriptTemplatesFolderInProject();
            string targetFolderInUnity = GetScriptTemplatesFolderOfUnity();

#if UNITY_EDITOR_WIN
            StringBuilder sb = new StringBuilder();
            var ingoreFiles = new string[] { "90-Shader__Compute Shader-NewComputeShader.compute" };

            // Clear template folder
            var files = Directory.GetFiles(targetFolderInUnity);
            var needToDeleteFiles = files.Where(f =>
            {
                var fileName = Path.GetFileNameWithoutExtension(f);
                if (fileName.StartsWith("90-Shader_"))
                {
                    if (ingoreFiles.Any(ignoreFile => ignoreFile.Equals(fileName, System.StringComparison.OrdinalIgnoreCase)))
                    {
                        return false;
                    }

                    return true;
                }

                return false;
            });

            foreach (var item in needToDeleteFiles)
            {
                sb.AppendLine(string.Format("del /q \"{0}\"", Path.GetFullPath(item)));
            }
#endif
            foreach (var template in Directory.GetFiles(srcFolderInProject, "*.txt"))
            {
                var templateName = Path.GetFileNameWithoutExtension(template);
                var temp = templateName.Split(new char[] { '-' }, 2);
                var nameInMenu = temp[0];
                var fileName = temp[1];

                if (!string.IsNullOrEmpty(nameInMenu) && !string.IsNullOrEmpty(fileName))
                {
                    var dstFileName = string.Format("{0}-{1}__{2}-{3}.txt", order, category, nameInMenu, fileName);
#if UNITY_EDITOR_WIN
                    sb.AppendLine(string.Format("copy /Y \"{0}\" \"{1}\"", Path.GetFullPath(template), Path.GetFullPath(Path.Combine(targetFolderInUnity, dstFileName))));
#else
                    File.Copy(template, Path.Combine(targetFolderInUnity, dstFileName), true);
#endif
                }
            }

#if UNITY_EDITOR_WIN
            var batchFile = Path.GetFullPath(Path.Combine(Application.dataPath, "..", "Library", "cp.bat"));
            File.WriteAllText(batchFile, sb.ToString(), Encoding.ASCII);
            
            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.FileName = batchFile;
            startInfo.Verb = "runas";
            startInfo.CreateNoWindow = true;
            startInfo.UseShellExecute = true;
            System.Diagnostics.Process.Start(startInfo);
#endif
        }

        private static string GetScriptTemplatesFolderInProject()
        {
            return Path.Combine(Application.dataPath, "ShaderlabVSCode", "ScriptTemplates");
        }

        private static string GetScriptTemplatesFolderOfUnity()
        {
            var contentsPath = EditorApplication.applicationContentsPath;
            return Path.Combine(contentsPath, "Resources", "ScriptTemplates");
        }
        #endregion
    }
}

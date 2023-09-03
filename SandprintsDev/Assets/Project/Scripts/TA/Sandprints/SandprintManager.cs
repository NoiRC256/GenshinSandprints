using UnityEngine;
using UnityEngine.Rendering;

namespace Sandprints
{
    public class SandprintManager : MonoBehaviour
    {
        public enum SimluationRate
        {
            Full = 0,
            Half = 1,
            Third = 2,
            Quater = 3,
        }

        public Transform FollowTarget;
        public int OrthographicSize = 15;
        public Camera ObjectCam;
        public Camera TerrainCam;
        [Tooltip("Render texture that contains object depth information captured from bottom.")]
        public RenderTexture ObjectRT;
        [Tooltip("Render texture that contains terrain depth information captured from top.")]
        public RenderTexture TerrainRT;
        public int RTDepth = 8;

        [Header("Sandprint Dynamics")]
        [SerializeField] private ComputeShader _dynamicsComputeShader;
        public float RecoverySpeed = 0.1f;
        public SimluationRate DynamicsSimulationRate = SimluationRate.Full;

        [Header("Sandprints")]
        public int RTWidth = 512;
        public int RTHeight = 512;
        public string CurrentIndentRTName = "_IndentRT";
        public string SandprintsRTName = "_SandprintsRT";

        [Header("Debug")]
        public bool DebugMode = false;
        public Material DebugMaterial;

        /// <summary>
        /// Render texture that contains normalized object depth.
        /// Red pixels correspond to indent.
        /// </summary>
        private RenderTexture _indentRT;
        /// <summary>
        /// Render texture that contains normalized object depth.
        /// Red pixels correspond to indent.
        /// </summary>
        private RenderTexture _currentIndentRT;
        /// <summary>
        /// Final render texture that contains all the necessary information for vertex displacement.
        /// Red pixels correspond to indent; Green pixels correspond to rise.
        /// </summary>
        private RenderTexture _finalRT;
        private int _mainKernel;
        private int _fadeKernel;
        private float _worldToTextureFactor;

        private void Awake()
        {
            // Setup render textures.
            _worldToTextureFactor = RTWidth / (OrthographicSize * 2f);

            _indentRT = new RenderTexture(RTWidth, RTHeight, RTDepth, RenderTextureFormat.RFloat);
            _indentRT.wrapMode = TextureWrapMode.Clamp;
            _indentRT.filterMode = FilterMode.Point;
            _indentRT.enableRandomWrite = true;
            _indentRT.Create();

            _currentIndentRT = new RenderTexture(RTWidth, RTHeight, RTDepth, RenderTextureFormat.RFloat);
            _currentIndentRT.wrapMode = TextureWrapMode.Clamp;
            _currentIndentRT.filterMode = FilterMode.Point;
            _currentIndentRT.Create();

            _finalRT = new RenderTexture(RTWidth, RTHeight, RTDepth, RenderTextureFormat.RGFloat);
            _finalRT.wrapMode = TextureWrapMode.Clamp;
            _finalRT.filterMode = FilterMode.Point;
            _finalRT.Create();

            // Setup compute shader.

            _mainKernel = _dynamicsComputeShader.FindKernel("CSMain");
            _dynamicsComputeShader.SetTexture(_mainKernel, "Result", _indentRT);
            _dynamicsComputeShader.SetTexture(_mainKernel, "CurResult", _currentIndentRT);
            _dynamicsComputeShader.SetTexture(_mainKernel, "ObjectDepthMap", ObjectRT);
            _dynamicsComputeShader.SetTexture(_mainKernel, "TerrainDepthMap", TerrainRT);

            _fadeKernel = _dynamicsComputeShader.FindKernel("CSFade");
            _dynamicsComputeShader.SetTexture(_fadeKernel, "Result", _indentRT);
            _dynamicsComputeShader.SetTexture(_fadeKernel, "CurResult", _currentIndentRT);

            _dynamicsComputeShader.SetInt("Width", RTWidth);
            _dynamicsComputeShader.SetInt("Height", RTHeight);
            _dynamicsComputeShader.SetFloat("OrthoCamSize", OrthographicSize);

            _dynamicsComputeShader.SetFloat("DeltaTime", Time.deltaTime);
            _dynamicsComputeShader.SetFloat("RecoverySpeed", RecoverySpeed);

            _dynamicsComputeShader.Dispatch(_mainKernel, RTWidth / 8, RTWidth / 8, 1);
            _dynamicsComputeShader.Dispatch(_fadeKernel, RTHeight / 8, RTHeight / 8, 1);

            // Setup shader.

            Shader.SetGlobalTexture(CurrentIndentRTName, _currentIndentRT);
            Shader.SetGlobalTexture(SandprintsRTName, _finalRT);
            if (DebugMode)
            {
                if (DebugMaterial != null) DebugMaterial.SetTexture("_BaseMap", _finalRT);
            }
        }

        public void Update()
        {
            if (FollowTarget != null) this.transform.position = FollowTarget.position;
            ObjectCam.orthographicSize = OrthographicSize;
            TerrainCam.orthographicSize = OrthographicSize;
            Shader.SetGlobalVector("_SandprintsCamPos", TerrainCam.transform.position);
            Shader.SetGlobalFloat("_SandprintsCamOrthoSize", OrthographicSize);

            CommandBuffer cmd = CommandBufferPool.Get();

            // Add new indent marks.
            // Current indent map --> indent map.
            //indentComputeShader.Dispatch(_mainKernel, rtWidth / 16, rtHeight / 16, 1);
            cmd.DispatchCompute(_dynamicsComputeShader, _mainKernel, RTWidth / 16, RTHeight / 16, 1);
            cmd.Blit(_indentRT, _currentIndentRT);

            _dynamicsComputeShader.SetFloat("DeltaTime", Time.deltaTime);

            //// Fade existing indent marks.
            //// Current indent map --> indent map.
            cmd.DispatchCompute(_dynamicsComputeShader, _fadeKernel, RTWidth / 16, RTHeight / 16, 1);
            cmd.Blit(_indentRT, _currentIndentRT);

            cmd.Blit(_currentIndentRT, _finalRT);
            Graphics.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }
    }
}
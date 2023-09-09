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
        public float CamHeightDistance = 5;
        public float CamViewDistance = 10;
        public float CamNearClip = 0.1f;
        public int CamOrthographicSize = 10;
        public Camera ObjectCam;
        [Tooltip("Render texture that contains object depth information captured from bottom.")]
        public RenderTexture ObjectDepthMap;
        public int RTDepth = 8;

        [Header("Sandprint Dynamics")]
        [SerializeField] private ComputeShader _dynamicsComputeShader;
        public float RecoverySpeed = 0.1f;
        public SimluationRate DynamicsSimulationRate = SimluationRate.Full;

        [Header("Sandprints")]
        public int RTWidth = 512;
        public int RTHeight = 512;
        public string ShaderCamOrthoSizeName = "_SandprintsCamOrthoSize";
        public string ShaderCamPosName = "_SandprintsCamPos";
        public string ShaderIndentMapName = "_SandprintsIndentMap";
        public string ShaderIndentValueToMeterName = "_SandprintsIndentValueToMeter";
        public string ShaderCenterIndentValueName = "_SandprintsCenterIndentValue";
        public Material IndentMapPostProcessMat = null;
        public int BlurIterations = 1;

        [Header("Debug")]
        public bool DebugMode = false;
        public Material DebugMaterial;

        /// <summary>
        /// Render texture that contains normalized object depth.
        /// Red pixels correspond to indent.
        /// </summary>
        private RenderTexture _indentMapPostFade;
        /// <summary>
        /// Render texture that contains normalized object depth.
        /// Red pixels correspond to indent.
        /// </summary>
        private RenderTexture _indentMapPreFade;
        /// <summary>
        /// Final render texture that contains all the necessary information for vertex displacement.
        /// Red pixels correspond to indent; Green pixels correspond to rise.
        /// </summary>
        private RenderTexture _finalIndentMap;
        private int _mainKernel;
        private float _worldToTextureFactor;
        private RenderTexture[] _blurDownsampleBuffer;
        private RenderTexture[] _blurUpsampleBuffer;
        private Vector3 _prevPosition;

        private float IndentValueToMeter => CamViewDistance;

        private void Awake()
        {
            _prevPosition = transform.position;
            _blurDownsampleBuffer = new RenderTexture[BlurIterations];
            _blurUpsampleBuffer = new RenderTexture[BlurIterations];

            // Setup camera.

            ObjectCam.transform.position = new Vector3(0f, -CamHeightDistance, 0f);
            ObjectCam.farClipPlane = CamViewDistance;
            ObjectCam.orthographicSize = CamOrthographicSize;

            // Setup render textures.

            _worldToTextureFactor = RTWidth / (CamOrthographicSize * 2f);

            _indentMapPreFade = new RenderTexture(RTWidth, RTHeight, RTDepth, RenderTextureFormat.RFloat);
            _indentMapPreFade.wrapMode = TextureWrapMode.Clamp;
            _indentMapPreFade.filterMode = FilterMode.Point;
            _indentMapPreFade.Create();

            _indentMapPostFade = new RenderTexture(RTWidth, RTHeight, RTDepth, RenderTextureFormat.RFloat);
            _indentMapPostFade.wrapMode = TextureWrapMode.Clamp;
            _indentMapPostFade.filterMode = FilterMode.Point;
            _indentMapPostFade.enableRandomWrite = true;
            _indentMapPostFade.Create();

            _finalIndentMap = new RenderTexture(RTWidth, RTHeight, RTDepth, RenderTextureFormat.RGFloat);
            _finalIndentMap.wrapMode = TextureWrapMode.Clamp;
            _finalIndentMap.filterMode = FilterMode.Point;
            _finalIndentMap.Create();

            // Setup compute shader.

            _mainKernel = _dynamicsComputeShader.FindKernel("CSMain");
            _dynamicsComputeShader.SetTexture(_mainKernel, "InputIndentMap", _indentMapPreFade);
            _dynamicsComputeShader.SetTexture(_mainKernel, "OutputIndentMap", _indentMapPostFade);
            _dynamicsComputeShader.SetTexture(_mainKernel, "ObjectDepthMap", ObjectDepthMap);

            _dynamicsComputeShader.SetFloat("DeltaTime", Time.deltaTime);
            _dynamicsComputeShader.SetFloat("RecoverySpeed", RecoverySpeed);
            _dynamicsComputeShader.SetFloat("IndentValueChange", 0f);

            // Setup shader.

            Shader.SetGlobalVector(ShaderCamPosName, ObjectCam.transform.position);
            Shader.SetGlobalFloat(ShaderCamOrthoSizeName, CamOrthographicSize);
            Shader.SetGlobalTexture(ShaderIndentMapName, _finalIndentMap);
            Shader.SetGlobalFloat(ShaderIndentValueToMeterName, IndentValueToMeter);
            Shader.SetGlobalFloat(ShaderCenterIndentValueName, CamHeightDistance / CamViewDistance);
            if (DebugMode)
            {
                if (DebugMaterial != null) DebugMaterial.SetTexture("_BaseMap", _finalIndentMap);
            }
        }

        public void Update()
        {
            if (FollowTarget != null) this.transform.position = FollowTarget.position;

            Vector3 deltaPos = transform.position - _prevPosition;
            float indentValueChangeByDeltaPos = -deltaPos.y / IndentValueToMeter;
            _dynamicsComputeShader.SetFloat("IndentValueDeltaHeightOffset", indentValueChangeByDeltaPos);
            Shader.SetGlobalVector(ShaderCamPosName, ObjectCam.transform.position);

            CommandBuffer cmd = CommandBufferPool.Get();

            // Fade out existing indent pixels, add new indent pixels.
            cmd.DispatchCompute(_dynamicsComputeShader, _mainKernel, RTWidth / 16, RTHeight / 16, 1);
            // Push the updated result back to prepare for the next frame.
            cmd.Blit(_indentMapPostFade, _indentMapPreFade);

            // Post processing.
            // Add green rim and blur.
            RenderTexture prefilterRT = RenderTexture.GetTemporary(RTWidth / 2, RTHeight / 2, 0, RenderTextureFormat.RFloat);
            cmd.Blit(_indentMapPreFade, prefilterRT);
            RenderTexture last = prefilterRT;
            for (int level = 0; level < BlurIterations; level++)
            {
                _blurDownsampleBuffer[level] = RenderTexture.GetTemporary(last.width / 2, last.height / 2, 0, RenderTextureFormat.RGFloat);
                cmd.Blit(last, _blurDownsampleBuffer[level], IndentMapPostProcessMat, 0);
                last = _blurDownsampleBuffer[level];
            }
            for (int level = BlurIterations - 1; level >= 0; level--)
            {
                _blurUpsampleBuffer[level] = RenderTexture.GetTemporary(last.width * 2, last.height * 2, 0, RenderTextureFormat.RGFloat);
                cmd.Blit(last, _blurUpsampleBuffer[level], IndentMapPostProcessMat, 1);
                last = _blurUpsampleBuffer[level];
            }
            cmd.Blit(last, _finalIndentMap);

            Graphics.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);

            for (int i = 0; i < BlurIterations; i++)
            {
                if (_blurDownsampleBuffer[i] != null)
                {
                    RenderTexture.ReleaseTemporary(_blurDownsampleBuffer[i]);
                    _blurDownsampleBuffer[i] = null;
                }
                if (_blurUpsampleBuffer[i] != null)
                {
                    RenderTexture.ReleaseTemporary(_blurUpsampleBuffer[i]);
                    _blurUpsampleBuffer[i] = null;
                }
            }
            RenderTexture.ReleaseTemporary(prefilterRT);
        }
    }
}
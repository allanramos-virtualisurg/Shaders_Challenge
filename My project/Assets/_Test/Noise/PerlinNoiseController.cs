using UnityEngine;

public class PerlinNoiseController : MonoBehaviour
{
    public ComputeShader perlinNoiseShader;
    public Renderer targetRenderer;

    public int textureResolution = 512;
    public float noiseScale = 1f;
    public float speed = 1f;
    
    
    private RenderTexture renderTexture;
    private int kernelHandle;

    // Cache de IDs para máxima performance
    private static readonly int ScaleID = Shader.PropertyToID("Scale");
    private static readonly int SpeedID = Shader.PropertyToID("Speed");
    private static readonly int TimeID = Shader.PropertyToID("Time");
    private static readonly int ResultID = Shader.PropertyToID("Result");

    void Start()
    {
        renderTexture = new RenderTexture(textureResolution, textureResolution, 0, RenderTextureFormat.ARGB32);
        renderTexture.enableRandomWrite = true;
        renderTexture.filterMode = FilterMode.Bilinear;
        renderTexture.wrapMode = TextureWrapMode.Repeat;
        renderTexture.Create();

        kernelHandle = perlinNoiseShader.FindKernel("CSMain");
        
        if (targetRenderer != null)
            targetRenderer.material.mainTexture = renderTexture;
    }

    void Update()
    {
        if (perlinNoiseShader == null) return;
        
        perlinNoiseShader.SetFloat(ScaleID, noiseScale);
        perlinNoiseShader.SetFloat(SpeedID, speed);
        perlinNoiseShader.SetFloat(TimeID, Time.time);
        
        perlinNoiseShader.SetTexture(kernelHandle, ResultID, renderTexture);
        
        int groupsX = Mathf.CeilToInt(renderTexture.width / 8.0f);
        int groupsY = Mathf.CeilToInt(renderTexture.height / 8.0f);
        
        perlinNoiseShader.Dispatch(kernelHandle, groupsX, groupsY, 1);
    }
    
    private void OnDestroy() // OnDestroy é mais garantido que OnDisable para limpeza de VRAM
    {
        if (renderTexture != null)
        {
            renderTexture.Release();
            Destroy(renderTexture);
        }
    }
}
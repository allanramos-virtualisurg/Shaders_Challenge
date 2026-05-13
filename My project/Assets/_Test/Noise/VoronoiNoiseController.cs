using UnityEngine;

public class VoronoiNoiseController : MonoBehaviour
{
    public ComputeShader voronoiComputeShader;
    public Renderer targetRenderer;
    
    public int textureResolution = 512;
    public float cellSize = 10f;
    public float speed = 1f;
    
    private RenderTexture renderTexture;
    private int kernel;
    
    private static readonly int CellSizeID = Shader.PropertyToID("CellSize");
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

        kernel = voronoiComputeShader.FindKernel("CSMain");
        
        if (targetRenderer != null)
        {
            targetRenderer.material.mainTexture = renderTexture;
        }
    }

    void Update()
    {
        if (voronoiComputeShader == null || renderTexture == null) return;
        
        voronoiComputeShader.SetFloat(CellSizeID, cellSize);
        voronoiComputeShader.SetFloat(SpeedID, speed);
        voronoiComputeShader.SetFloat(TimeID, Time.time);
        voronoiComputeShader.SetTexture(kernel, ResultID, renderTexture);
        
        int threadGroupsX = Mathf.CeilToInt(textureResolution / 8.0f);
        int threadGroupsY = Mathf.CeilToInt(textureResolution / 8.0f);
        
        voronoiComputeShader.Dispatch(kernel, threadGroupsX, threadGroupsY, 1);
    }

    // Limpeza de memória ao destruir o objeto
    private void OnDestroy()
    {
        if (renderTexture != null)
        {
            renderTexture.Release();
        }
    }
}
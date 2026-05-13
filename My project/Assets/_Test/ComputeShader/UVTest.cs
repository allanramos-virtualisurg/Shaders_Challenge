using UnityEngine;

public class UVTest : MonoBehaviour
{
    public ComputeShader computeShader;
    public Renderer targetRenderer;

    RenderTexture renderTexture;

    void Start()
    {
        renderTexture = new RenderTexture(256, 256, 24);
        renderTexture.enableRandomWrite = true;
        renderTexture.Create();

        int kernel = computeShader.FindKernel("CSMain");

        computeShader.SetTexture(kernel, "Result", renderTexture);
        computeShader.Dispatch(kernel, 32, 32, 1);

        targetRenderer.material.mainTexture = renderTexture;
    }
}
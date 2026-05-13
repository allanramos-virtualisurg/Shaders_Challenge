using UnityEngine;

public class ComputeStartTest : MonoBehaviour
{
    public ComputeShader computeShader;
    public Renderer targetRenderer;

    public Color colorA;
    public Color colorB;
    //public float value;

    RenderTexture renderTexture;

    void Start()
    {

        renderTexture = new RenderTexture(256*2, 256*2, 24);
        renderTexture.enableRandomWrite = true;
        renderTexture.Create();
    }

    private void Update()
    {
        int kernel = computeShader.FindKernel("CSMain");

        computeShader.SetVector("colorA", colorA);
        computeShader.SetVector("colorB", colorB);
        //computeShader.SetFloat("t", value);

        computeShader.SetTexture(kernel, "Result", renderTexture);
        computeShader.Dispatch(kernel, 32*2, 32*2, 1);

        targetRenderer.material.mainTexture = renderTexture;
    }

}
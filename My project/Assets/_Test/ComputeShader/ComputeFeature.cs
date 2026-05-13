using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ComputeFeature : ScriptableRendererFeature
{
    class ComputePass : ScriptableRenderPass
    {
        public ComputeShader computeShader;
        RenderTexture renderTexture;

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (renderTexture == null)
            {
                renderTexture = new RenderTexture(256, 256, 0);
                renderTexture.enableRandomWrite = true;
                renderTexture.Create();
            }

            int kernel = computeShader.FindKernel("CSMain");

            computeShader.SetTexture(kernel, "Result", renderTexture);
            computeShader.Dispatch(kernel, 32, 32, 1);

            CommandBuffer cmd = CommandBufferPool.Get("Compute Pass");
            cmd.Blit(renderTexture, renderingData.cameraData.renderer.cameraColorTargetHandle);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }

    ComputePass pass;

    public ComputeShader computeShader;

    public override void Create()
    {
        pass = new ComputePass();
        pass.computeShader = computeShader;
        pass.renderPassEvent = RenderPassEvent.AfterRendering;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(pass);
    }
}
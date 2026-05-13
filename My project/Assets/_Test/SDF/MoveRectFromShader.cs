using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MoveRectFromShader : MonoBehaviour
{
    public Renderer targetRenderer;

    void Update()
    {
        targetRenderer.material.SetMatrix("_WorldToLocalMatrix", transform.worldToLocalMatrix);  
    }
}

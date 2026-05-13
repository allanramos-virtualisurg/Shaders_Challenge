using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SDFMovementController : MonoBehaviour
{
    public Renderer targetRenderer;
    
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        targetRenderer.material.SetMatrix("_WorldToLocalMatrix", transform.worldToLocalMatrix);
    }
}

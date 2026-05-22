using UnityEngine;

public class ShaderContact : MonoBehaviour {
    public Transform contactObject;
    public Material tessMaterial;

    void Update() {
        if(contactObject != null) {
            tessMaterial.SetVector("_ContactPos", contactObject.position);
        }
    }
}
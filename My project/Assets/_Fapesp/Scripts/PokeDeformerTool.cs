using UnityEngine;

[ExecuteAlways]
public class PokeDeformerTool : MonoBehaviour
{
    [Header("Target")]
    [Tooltip("The Material of the object to be deformed")]
    public Material targetMaterial;

    [Header("Tool Points")]
    [Tooltip("Empty GameObject placed at the tip of the tool")]
    public Transform toolTip;
    [Tooltip("Empty GameObject placed further back along the tool shaft (defines how deep you can push without passing through)")]
    public Transform toolBase;

    [Header("Deformation Settings")]
    [Tooltip("Inner radius of the tool tip")]
    public float tipRadius = 0.1f;
    [Tooltip("Surrounding area that gets pulled along smoothly")]
    [Min(0f)]
    public float falloffRadius = 0.6f;
    [Tooltip("1.0 = surface stays exactly in front of the tool tip")]
    public float pushMultiplier = 1.0f;

    [Header("Gizmos")]
    public bool showGizmos = true;
    public Color coreGizmoColor = new Color(0f, 1f, 1f, 0.9f);
    public Color falloffGizmoColor = new Color(1f, 0.85f, 0f, 0.45f);

    private static readonly int PointAID = Shader.PropertyToID("_CapsulePointA");
    private static readonly int PointBID = Shader.PropertyToID("_CapsulePointB");
    private static readonly int RadiusID = Shader.PropertyToID("_CapsuleRadius");
    private static readonly int FalloffID = Shader.PropertyToID("_DeformFalloff");
    private static readonly int MultiplierID = Shader.PropertyToID("_DeformMultiplier");

    void Update()
    {
        if (targetMaterial == null || toolTip == null) return;

        Vector3 pointA = toolTip.position;
        // If no base is assigned, automatically project 2 units backwards along the tool's up/forward axis
        Vector3 pointB = toolBase != null ? toolBase.position : (pointA - toolTip.forward * 2.0f);

        targetMaterial.SetVector(PointAID, pointA);
        targetMaterial.SetVector(PointBID, pointB);
        targetMaterial.SetFloat(RadiusID, tipRadius);
        targetMaterial.SetFloat(FalloffID, falloffRadius);
        targetMaterial.SetFloat(MultiplierID, pushMultiplier);
    }

    private void OnDrawGizmos()
    {
        if (!showGizmos || toolTip == null) return;

        Vector3 pA = toolTip.position;
        Vector3 pB = toolBase != null ? toolBase.position : (pA - toolTip.forward * 2.0f);

        DrawCapsuleGizmo(pA, pB, tipRadius, coreGizmoColor);

        if (falloffRadius > 0.001f)
        {
            DrawCapsuleGizmo(pA, pB, tipRadius + falloffRadius, falloffGizmoColor);
        }
    }

    private void DrawCapsuleGizmo(Vector3 pA, Vector3 pB, float radius, Color color)
    {
        Gizmos.color = color;
        Gizmos.DrawWireSphere(pA, radius);

        if (pA != pB)
        {
            Gizmos.DrawWireSphere(pB, radius);

            Vector3 direction = (pB - pA).normalized;
            Vector3 up = Vector3.Cross(direction, Vector3.right);
            if (up.sqrMagnitude < 0.001f) up = Vector3.Cross(direction, Vector3.forward);
            up = up.normalized * radius;
            Vector3 right = Vector3.Cross(direction, up).normalized * radius;

            Gizmos.DrawLine(pA, pB);
            Gizmos.DrawLine(pA + up, pB + up);
            Gizmos.DrawLine(pA - up, pB - up);
            Gizmos.DrawLine(pA + right, pB + right);
            Gizmos.DrawLine(pA - right, pB - right);
        }
    }
}
using UnityEngine;
using UnityEngine.Serialization;

public class FurInteraction : MonoBehaviour
{
    [Header("Interaction Settings")]
    [SerializeField] private float m_interactionRadius = 2.0f;
    [SerializeField] private float m_bendStrength = 0.65f;
    [SerializeField] private LayerMask m_interactionLayer;
    
    private Material furMaterial;
    private Camera mainCamera;
    
    private void Start()
    {
        mainCamera = Camera.main;
        // Get the material instance
        Renderer renderer = GetComponent<Renderer>();
        furMaterial = renderer.material; // This creates an instance of the material
    }

    private void Update()
    {
        HandleInteraction();
    }

    private void HandleInteraction()
    {
        // Reset interaction when mouse button is not pressed
        if (!Input.GetMouseButton(0))
        {
            furMaterial.SetVector("_InteractionPoint", new Vector4(0, -9999, 0, 0)); // Set to far away point
            return;
        }

        Ray ray = mainCamera.ScreenPointToRay(Input.mousePosition);
        RaycastHit hit;

        if (Physics.Raycast(ray, out hit, 100.0f, m_interactionLayer) && furMaterial)
        {
            // Convert hit point to local space
            Vector3 localHitPoint = hit.point; //transform.InverseTransformPoint(hit.point);
            
            // Set the interaction point and parameters
            Debug.Log(localHitPoint);
            furMaterial.SetVector("_InteractionPoint", localHitPoint);
            furMaterial.SetFloat("_InteractionRadius", m_interactionRadius);
            furMaterial.SetFloat("_InteractionStrength", m_bendStrength);
        }
    }
}
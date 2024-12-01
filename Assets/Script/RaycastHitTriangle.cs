// This script draws a debug line around mesh triangles
// as you move the mouse over them.
using UnityEngine;
using System.Collections;

public class RaycastHitTriangle : MonoBehaviour
{
    Camera cam;

    void Start()
    {
        cam = GetComponent<Camera>();
    }

    void Update()
    {
        RaycastHit hit;
        if (!Physics.Raycast(cam.ScreenPointToRay(Input.mousePosition), out hit))
            return;

        MeshCollider meshCollider = hit.collider as MeshCollider;
        if (meshCollider == null || meshCollider.sharedMesh == null)
            return;

        Mesh mesh = meshCollider.sharedMesh;
        Vector3[] vertices = mesh.vertices;
        Vector2[] uv2 = new Vector2[vertices.Length]; //holds (x, y)
        Vector2[] uv3 = new Vector2[vertices.Length]; //holds (z, 0)
        int[] triangles = mesh.triangles;
        Vector3 p0 = vertices[triangles[hit.triangleIndex * 3 + 0]];
        Vector3 p1 = vertices[triangles[hit.triangleIndex * 3 + 1]];
        Vector3 p2 = vertices[triangles[hit.triangleIndex * 3 + 2]];
        Transform hitTransform = hit.collider.transform;
        
        Vector3 wP0 = hitTransform.TransformPoint(p0);
        Vector3 wP1 = hitTransform.TransformPoint(p1);
        Vector3 wP2 = hitTransform.TransformPoint(p2);
        Debug.DrawLine(wP0, wP1);
        Debug.DrawLine(wP1, wP2);
        Debug.DrawLine(wP2, wP0);
        
        //displace vertices away from the hit point
        Vector3 triangleCenter = (p0 + p1 + p2) / 3;
        Vector3 hitLocalPos = hitTransform.InverseTransformPoint(hit.point);
        float minimumDistance = 0.2f, additionalDistance = 0.3f;
        Vector3 newP0 = (p0 - triangleCenter).normalized * (minimumDistance + additionalDistance * (1 - Mathf.Clamp(Vector3.Distance(hitLocalPos, p0) / Vector3.Distance(triangleCenter, p0), 0, 1)));
        Vector3 newP1 = (p1 - triangleCenter).normalized * (minimumDistance + additionalDistance * (1 - Mathf.Clamp(Vector3.Distance(hitLocalPos, p1) / Vector3.Distance(triangleCenter, p1), 0, 1)));
        Vector3 newP2 = (p2 - triangleCenter).normalized * (minimumDistance + additionalDistance * (1 - Mathf.Clamp(Vector3.Distance(hitLocalPos, p2) / Vector3.Distance(triangleCenter, p2), 0, 1)));
        uv2[triangles[hit.triangleIndex * 3 + 0]] = newP0;
        uv2[triangles[hit.triangleIndex * 3 + 1]] = newP1;
        uv2[triangles[hit.triangleIndex * 3 + 2]] = newP2;
        uv3[triangles[hit.triangleIndex * 3 + 0]] = new Vector2(newP0.z, 0);
        uv3[triangles[hit.triangleIndex * 3 + 1]] = new Vector2(newP1.z, 0);
        uv3[triangles[hit.triangleIndex * 3 + 2]] = new Vector2(newP2.z, 0);

        mesh.uv2 = uv2;
        mesh.uv3 = uv3;
    }
}
// This script draws a debug line around mesh triangles
// as you move the mouse over them.
using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using System.Linq;

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
        Vector2[] uv3 = new Vector2[vertices.Length]; //holds (z, w)
        int[] triangles = mesh.triangles;
        Transform hitTransform = hit.collider.transform;
        Vector3 hitLocalPos = hitTransform.InverseTransformPoint(hit.point);
        float sphereRadius = 1.5f;
        List<int> trianglesInsideSphereIndexList = GetTrianglesInsideSphere(vertices, triangles, hitLocalPos, sphereRadius);
        foreach (int i in trianglesInsideSphereIndexList)
        {
            Vector3 p0 = vertices[triangles[i + 0]];
            Vector3 p1 = vertices[triangles[i + 1]];
            Vector3 p2 = vertices[triangles[i + 2]];
            
            Vector3 wP0 = hitTransform.TransformPoint(p0);
            Vector3 wP1 = hitTransform.TransformPoint(p1);
            Vector3 wP2 = hitTransform.TransformPoint(p2);
            Debug.DrawLine(wP0, wP1);
            Debug.DrawLine(wP1, wP2);
            Debug.DrawLine(wP2, wP0);
            
            //displace vertices away from the hit point
            Vector3 triangleCenter = (p0 + p1 + p2) / 3;
            float minimumFactor = 2f, additionalFactor = 4f;
            Vector3 newP0 = (p0 - hitLocalPos).normalized;
            Vector3 newP1 = (p1 - hitLocalPos).normalized;
            Vector3 newP2 = (p2 - hitLocalPos).normalized;
            uv2[triangles[i + 0]] = newP0;
            uv2[triangles[i + 1]] = newP1;
            uv2[triangles[i + 2]] = newP2;
            uv3[triangles[i + 0]] = new Vector2(newP0.z, minimumFactor + additionalFactor * (1 - Mathf.Clamp(Vector3.Distance(hitLocalPos, p0) / Vector3.Distance(triangleCenter, p0), 0, 1)));
            uv3[triangles[i + 1]] = new Vector2(newP1.z, minimumFactor + additionalFactor * (1 - Mathf.Clamp(Vector3.Distance(hitLocalPos, p1) / Vector3.Distance(triangleCenter, p1), 0, 1)));
            uv3[triangles[i + 2]] = new Vector2(newP2.z, minimumFactor + additionalFactor * (1 - Mathf.Clamp(Vector3.Distance(hitLocalPos, p2) / Vector3.Distance(triangleCenter, p2), 0, 1)));
        }
        
        mesh.uv2 = uv2;
        mesh.uv3 = uv3;
    }
    
    bool IsInsideSphere(Vector3 vertex, Vector3 sphereCenter, float sphereRadius) => Vector3.Distance(vertex, sphereCenter) <= sphereRadius;

    List<int> GetTrianglesInsideSphere(Vector3[] vertices, int[] triangles, Vector3 sphereCenter, float sphereRadius) => Enumerable.Range(0, triangles.Length).Where(v => IsInsideSphere(vertices[triangles[v]], sphereCenter, sphereRadius)).Select(t => t - t%3).Distinct().ToList();
}
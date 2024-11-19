using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;


public class ShellLayers : MonoBehaviour
{
    [Header("Core Settings")] 
    public Mesh m_shellMesh;
    public Shader m_shellShader;
    
    [Header("Shader Properties")]
    public int m_shellCount = 10;
    public float m_shellLength = 0.5f;
    public float m_density = 100.0f;
    public float m_noiseMin = 0.0f;
    public float m_noiseMax = 1.0f;
    public float m_thiccness = 1.0f;
    public float m_curvature = 0.25f;
    public Color m_furColor;

    private Material m_material;
    private GameObject[] m_shells;
    
    private void OnEnable()
    {
        m_shells = new GameObject[m_shellCount];
        m_material = new Material(m_shellShader);

        for (int i = 0; i < m_shellCount; i++)
        {
            // Making new shell layer - needs a mesh filter and a mesh renderer
            m_shells[i] = new GameObject();
            m_shells[i].AddComponent<MeshFilter>();
            m_shells[i].AddComponent<MeshRenderer>();
            m_shells[i].transform.SetParent(transform, false);

            MeshFilter shellMesh = m_shells[i].GetComponent<MeshFilter>();
            MeshRenderer shellRend = m_shells[i].GetComponent<MeshRenderer>();

            shellMesh.mesh = m_shellMesh;
            shellRend.material = m_material;
            
            /*
             *
             * All the properties need to be set
             *
             * int _ShellInd;
             * int _ShellCount;
             * float _ShellLength;
             * float _Density;
             * float _NoiseMin;
             * float _NoiseMax;
             * float _Thiccness;
             * float4 _FurColor;
             *
             */
            
            shellRend.material.SetInt("_ShellInd", i);
            shellRend.material.SetInt("_ShellCount", m_shellCount);
            shellRend.material.SetFloat("_ShellLength", m_shellLength);
            shellRend.material.SetFloat("_Density", m_density);
            shellRend.material.SetFloat("_NoiseMin", m_noiseMin);
            shellRend.material.SetFloat("_NoiseMax", m_noiseMax);
            shellRend.material.SetFloat("_Thiccness", m_thiccness);
            shellRend.material.SetFloat("_Curvature", m_curvature);
            shellRend.material.SetColor("_FurColor", m_furColor);
        }
    }
}

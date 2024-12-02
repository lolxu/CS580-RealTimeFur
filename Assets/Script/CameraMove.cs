using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraMove : MonoBehaviour
{
    public float m_moveSpeed = 1.0f;
    public float m_turnSpeed = 1.0f;
    
    void Update()
    {
        Vector3 moveDir = Vector3.zero;
        if (Input.GetKey(KeyCode.W))
        {
            moveDir += transform.forward;
        }

        if (Input.GetKey(KeyCode.S))
        {
            moveDir -= transform.forward;
        }

        if (Input.GetKey(KeyCode.A))
        {
            moveDir -= transform.right;
        }

        if (Input.GetKey(KeyCode.D))
        {
            moveDir += transform.right;
        }

        transform.position += moveDir * m_moveSpeed * Time.deltaTime;

        Vector3 euler = transform.localRotation.eulerAngles;

        if (Input.GetKey(KeyCode.LeftArrow))
        {
            euler.y -= m_turnSpeed * Time.deltaTime;
        }

        if (Input.GetKey(KeyCode.RightArrow))
        {
            euler.y += m_turnSpeed * Time.deltaTime;
        }
        
        if (Input.GetKey(KeyCode.UpArrow))
        {
            euler.x -= m_turnSpeed * Time.deltaTime;
        }
        
        if (Input.GetKey(KeyCode.DownArrow))
        {
            euler.x += m_turnSpeed * Time.deltaTime;
        }

        transform.localRotation = Quaternion.Euler(euler);
    }
}

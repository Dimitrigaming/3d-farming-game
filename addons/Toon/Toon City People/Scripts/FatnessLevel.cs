using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace TCP_Fatness_Level
{
    [ExecuteInEditMode]
    public class FatnessLevel : MonoBehaviour
    {
        [Range(0, 100)]

        public int MasterFatSlider;

        void OnValidate()
        {
            SetFatValueForGameObject(MasterFatSlider);
        }

        public void SetFatValueForGameObject(int value)
        {
            foreach (Transform t in this.transform)
            {
                SkinnedMeshRenderer meshRenderer = t.GetComponent<SkinnedMeshRenderer>();
                if (meshRenderer != null && meshRenderer.sharedMesh.blendShapeCount > 0)
                {
                    for (int i = 0; i < meshRenderer.sharedMesh.blendShapeCount; i++)
                    {
                        if (meshRenderer.sharedMesh.GetBlendShapeName(i) == "Fat")
                        {
                            meshRenderer.SetBlendShapeWeight(i, value);
                        }
                    }
                }
            }
        }
    }
}

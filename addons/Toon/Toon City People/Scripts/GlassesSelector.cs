using System.Collections.Generic;
using UnityEngine;

namespace GlassesSelector
{

    public class GlassesSelector : MonoBehaviour
    {
        public const int MAXIMUM_NUMBER_GLASSES = 21
;
        [Range(0, MAXIMUM_NUMBER_GLASSES - 1)]
        public int Glass;
        public GameObject[] Glasses = new GameObject[MAXIMUM_NUMBER_GLASSES];


        void OnValidate()
        {
		ValidateObject(Glass, Glasses);

        }

        public void ValidateObject(int selectedIndex, GameObject[] objects)
        {
            if (selectedIndex > objects.Length)
                selectedIndex = objects.Length;

            for (int i = 0; i < objects.Length; i++)
            {
                if (objects[i] != null)
                    objects[i].SetActive(i == selectedIndex);
            }
        }
    }
}

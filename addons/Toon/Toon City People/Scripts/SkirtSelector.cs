using System.Collections.Generic;
using UnityEngine;

namespace SkirtSelector
{

    public class SkirtSelector : MonoBehaviour
    {
        public const int MAXIMUM_NUMBER_SKIRTS = 5
;
        [Range(0, MAXIMUM_NUMBER_SKIRTS - 1)]
        public int Skirt;
        public GameObject[] Skirts = new GameObject[MAXIMUM_NUMBER_SKIRTS];


        void OnValidate()
        {
		ValidateObject(Skirt, Skirts);

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

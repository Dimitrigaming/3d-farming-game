using System.Collections.Generic;
using UnityEngine;

namespace PantSelector
{

    public class PantSelector : MonoBehaviour
    {
        public const int MAXIMUM_NUMBER_PANTS = 5
;
        [Range(0, MAXIMUM_NUMBER_PANTS - 1)]
        public int Pant;
        public GameObject[] Pants = new GameObject[MAXIMUM_NUMBER_PANTS];


        void OnValidate()
        {
		ValidateObject(Pant, Pants);

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

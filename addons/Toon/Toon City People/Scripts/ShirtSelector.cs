using System.Collections.Generic;
using UnityEngine;

namespace ShirtSelector
{

    public class ShirtSelector : MonoBehaviour
    {
        public const int MAXIMUM_NUMBER_SHIRTS = 5
;
        [Range(0, MAXIMUM_NUMBER_SHIRTS - 1)]
        public int Shirt;
        public GameObject[] Shirts = new GameObject[MAXIMUM_NUMBER_SHIRTS];


        void OnValidate()
        {
		ValidateObject(Shirt, Shirts);

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

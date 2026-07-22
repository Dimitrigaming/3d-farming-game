using System.Collections.Generic;
using UnityEngine;

namespace ShoeSelector
{

    public class ShoeSelector : MonoBehaviour
    {
        public const int MAXIMUM_NUMBER_SHOES = 5
;
        [Range(0, MAXIMUM_NUMBER_SHOES - 1)]
        public int Shoe;
        public GameObject[] Shoes = new GameObject[MAXIMUM_NUMBER_SHOES];


        void OnValidate()
        {
		ValidateObject(Shoe, Shoes);

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

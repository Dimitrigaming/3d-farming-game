using System.Collections.Generic;
using UnityEngine;

namespace HairSelector
{

    public class HairSelector : MonoBehaviour
    {
        public const int MAXIMUM_NUMBER_HAIRSTYLES = 51;
        [Range(0, MAXIMUM_NUMBER_HAIRSTYLES - 1)]
        public int Hairstyle;
        public GameObject[] Hairstyles = new GameObject[MAXIMUM_NUMBER_HAIRSTYLES];


        void OnValidate()
        {
		ValidateObject(Hairstyle, Hairstyles);

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

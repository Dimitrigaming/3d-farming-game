using System.Collections.Generic;
using UnityEngine;

namespace DressSelector
{

    public class DressSelector : MonoBehaviour
    {
        public const int MAXIMUM_NUMBER_DRESSES = 5
;
        [Range(0, MAXIMUM_NUMBER_DRESSES - 1)]
        public int Dress;
        public GameObject[] Dresses = new GameObject[MAXIMUM_NUMBER_DRESSES];


        void OnValidate()
        {
		ValidateObject(Dress, Dresses);

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

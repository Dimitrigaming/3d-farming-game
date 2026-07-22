using System.Collections.Generic;
using UnityEngine;

namespace BraceletSelector
{

    public class BraceletSelector : MonoBehaviour
    {
        public const int MAXIMUM_NUMBER_BRACELETS = 13
;
        [Range(0, MAXIMUM_NUMBER_BRACELETS - 1)]
        public int Bracelet;
        public GameObject[] Bracelets = new GameObject[MAXIMUM_NUMBER_BRACELETS];


        void OnValidate()
        {
		ValidateObject(Bracelet, Bracelets);

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

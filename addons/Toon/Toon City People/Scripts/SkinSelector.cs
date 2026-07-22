using System.Collections.Generic;
using UnityEngine;

namespace SkinSelector
{

    public class SkinSelector : MonoBehaviour
    {
        public const int MAXIMUM_NUMBER_SKINS = 5
;
        [Range(0, MAXIMUM_NUMBER_SKINS - 1)]
        public int Skin;
        public GameObject[] Skins = new GameObject[MAXIMUM_NUMBER_SKINS];


        void OnValidate()
        {
		ValidateObject(Skin, Skins);

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

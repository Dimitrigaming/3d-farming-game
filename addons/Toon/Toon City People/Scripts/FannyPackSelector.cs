using System.Collections.Generic;
using UnityEngine;

namespace FannyPackSelector
{

    public class FannyPackSelector : MonoBehaviour
    {
        public const int MAXIMUM_NUMBER_FANNYPACKS = 6
;
        [Range(0, MAXIMUM_NUMBER_FANNYPACKS - 1)]
        public int FannyPack;
        public GameObject[] FannyPacks = new GameObject[MAXIMUM_NUMBER_FANNYPACKS];


        void OnValidate()
        {
		ValidateObject(FannyPack, FannyPacks);

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

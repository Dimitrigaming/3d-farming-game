using System.Collections.Generic;
using UnityEngine;

namespace HatSelector
{

    public class HatSelector : MonoBehaviour
    {
        public const int MAXIMUM_NUMBER_HATS = 26
;
        [Range(0, MAXIMUM_NUMBER_HATS - 1)]
        public int Hat;
        public GameObject[] Hats = new GameObject[MAXIMUM_NUMBER_HATS];


        void OnValidate()
        {
		ValidateObject(Hat, Hats);

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

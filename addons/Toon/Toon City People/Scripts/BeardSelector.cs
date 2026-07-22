using System.Collections.Generic;
using UnityEngine;

namespace BeardSelector
{

    public class BeardSelector : MonoBehaviour
    {
        public const int MAXIMUM_NUMBER_BEARDS = 46
;
        [Range(0, MAXIMUM_NUMBER_BEARDS - 1)]
        public int Beard;
        public GameObject[] Beards = new GameObject[MAXIMUM_NUMBER_BEARDS];


        void OnValidate()
        {
		ValidateObject(Beard, Beards);

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

using System.Collections.Generic;
using UnityEngine;

namespace ChokerSelector
{

    public class ChokerSelector : MonoBehaviour
    {
        public const int MAXIMUM_NUMBER_CHOKERS = 4
;
        [Range(0, MAXIMUM_NUMBER_CHOKERS - 1)]
        public int Choker;
        public GameObject[] Chokers = new GameObject[MAXIMUM_NUMBER_CHOKERS];


        void OnValidate()
        {
		ValidateObject(Choker, Chokers);

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

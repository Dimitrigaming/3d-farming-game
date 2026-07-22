using System.Collections.Generic;
using UnityEngine;

namespace LegSelector
{

    public class LegSelector : MonoBehaviour
    {
        public const int MAXIMUM_NUMBER_LEGS = 5
;
        [Range(0, MAXIMUM_NUMBER_LEGS - 1)]
        public int Leg;
        public GameObject[] Legs = new GameObject[MAXIMUM_NUMBER_LEGS];


        void OnValidate()
        {
		ValidateObject(Leg, Legs);

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
